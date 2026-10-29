import { createHash } from 'crypto';
import { defaultSeedCredentials } from '../src/common/prisma/demo-seed';
import { createTestApp, type TestApp } from './support/app';
import { bearer, loginForeman, workerSession, type ForemanSession } from './support/auth';
import { resetDb } from './support/db';

/**
 * Foreman sessions, refresh rotation and the worker QR flow, end to end.
 *
 * `POST /foreman/login` allows 5 calls a minute per client, every call counts
 * (a 400 or 401 included), and every test here shares one app. So the order is
 * deliberate: the QR tests reuse the `beforeAll` session, the session tests
 * that destroy their session log in again (attempts 4 and 5), and the
 * rate-limit test runs last, where its first attempt is the 6th.
 */
describe('auth (e2e)', () => {
  let t: TestApp;
  let foreman: ForemanSession;
  const { foremanEmail, foremanPassword } = defaultSeedCredentials();

  beforeAll(async () => {
    t = await createTestApp();
    await resetDb(t.prisma);
    foreman = await loginForeman(t);
  });

  afterAll(async () => {
    await t.close();
  });

  describe('foreman login', () => {
    it('returns an access token, a refresh token and the user', () => {
      expect(foreman.accessToken).toEqual(expect.any(String));
      expect(foreman.refreshToken).toEqual(expect.any(String));
      expect(foreman.user).toMatchObject({
        id: 'foreman_local',
        role: 'foreman',
        companyId: 'demo-company',
      });
    });

    it('rejects a wrong password with INVALID_CREDENTIALS and the error envelope', async () => {
      const res = await t.http
        .post('/foreman/login')
        .send({ email: foremanEmail, password: 'not-the-password' })
        .expect(401);
      expect(res.body).toMatchObject({ error: { code: 'INVALID_CREDENTIALS' } });
      expect(res.headers['x-trace-id']).toEqual(expect.any(String));
    });

    it('validates the body before touching the database', async () => {
      const res = await t.http.post('/foreman/login').send({ email: 'nope' }).expect(400);
      expect(res.body.error).toMatchObject({ code: 'VALIDATION_FAILED' });
      expect(res.body.error.field).toEqual(expect.any(String));
    });
  });

  describe('worker QR login', () => {
    async function mintTicket(employeeId = 'e1') {
      const res = await t.http
        .post(`/employees/${employeeId}/login-ticket`)
        .set(bearer(foreman.accessToken))
        .expect(201);
      return res.body as { ticketId: string; qrPayload: string; expiresInSeconds: number };
    }

    it('mints a ticket whose QR payload names the employee', async () => {
      const ticket = await mintTicket('e1');
      expect(ticket.expiresInSeconds).toBeGreaterThan(0);
      expect(JSON.parse(ticket.qrPayload)).toMatchObject({
        type: 'foreman_worker_login_ticket',
        ticketId: ticket.ticketId,
        employeeId: 'e1',
      });
    });

    it('redeems by ticketId, and the worker token identifies the employee', async () => {
      const ticket = await mintTicket('e1');
      const res = await t.http
        .post('/worker/login-tickets/redeem')
        .send({ ticketId: ticket.ticketId })
        .expect(200);
      expect(res.body.worker).toMatchObject({
        employeeId: 'e1',
        role: 'worker',
        companyId: 'demo-company',
      });

      const me = await t.http.get('/worker/me').set(bearer(res.body.accessToken)).expect(200);
      expect(me.body).toMatchObject({ employeeId: 'e1', companyId: 'demo-company' });
    });

    it('redeems the raw scanned payload, as the phone sends it', async () => {
      const ticket = await mintTicket('e2');
      const res = await t.http
        .post('/worker/login-tickets/redeem')
        .send({ payload: ticket.qrPayload })
        .expect(200);
      expect(res.body.worker.employeeId).toBe('e2');
    });

    it('refuses a replayed ticket with 409', async () => {
      const ticket = await mintTicket('e1');
      await t.http
        .post('/worker/login-tickets/redeem')
        .send({ ticketId: ticket.ticketId })
        .expect(200);
      const replay = await t.http
        .post('/worker/login-tickets/redeem')
        .send({ ticketId: ticket.ticketId })
        .expect(409);
      expect(replay.body.error.code).toBe('TICKET_ALREADY_REDEEMED');
    });

    it('refuses an expired ticket with 410', async () => {
      const ticket = await mintTicket('e1');
      await t.prisma.workerLoginTicket.updateMany({
        where: { ticketHash: sha256(ticket.ticketId) },
        data: { expiresAt: new Date(Date.now() - 1000) },
      });
      const res = await t.http
        .post('/worker/login-tickets/redeem')
        .send({ ticketId: ticket.ticketId })
        .expect(410);
      expect(res.body.error.code).toBe('TICKET_EXPIRED');
    });

    it('refuses an unknown ticket with 404', async () => {
      const res = await t.http
        .post('/worker/login-tickets/redeem')
        .send({ ticketId: 'never-issued' })
        .expect(404);
      expect(res.body.error.code).toBe('TICKET_NOT_FOUND');
    });

    it('will not mint for, or redeem as, a deactivated employee', async () => {
      const ticket = await mintTicket('e3');
      await t.prisma.employee.update({ where: { id: 'e3' }, data: { isActive: false } });

      const redeem = await t.http
        .post('/worker/login-tickets/redeem')
        .send({ ticketId: ticket.ticketId })
        .expect(403);
      expect(redeem.body.error.code).toBe('ACCOUNT_DISABLED');

      const mint = await t.http
        .post('/employees/e3/login-ticket')
        .set(bearer(foreman.accessToken))
        .expect(409);
      expect(mint.body.error.code).toBe('ACCOUNT_DISABLED');

      await t.prisma.employee.update({ where: { id: 'e3' }, data: { isActive: true } });
    });

    it('a worker token cannot mint tickets for anyone', async () => {
      const worker = await workerSession(t, foreman.accessToken, 'e1');
      const res = await t.http
        .post('/employees/e2/login-ticket')
        .set(bearer(worker.accessToken))
        .expect(403);
      expect(res.body.error.code).toBe('FORBIDDEN');
    });
  });

  describe('session', () => {
    it('describes the principal on /auth/me', async () => {
      const res = await t.http.get('/auth/me').set(bearer(foreman.accessToken)).expect(200);
      expect(res.body).toMatchObject({
        role: 'foreman',
        companyId: 'demo-company',
        userId: 'foreman_local',
      });
    });

    it('rotates the refresh token and refuses the old one as reused', async () => {
      const rotated = await t.http
        .post('/auth/refresh')
        .send({ refreshToken: foreman.refreshToken })
        .expect(200);
      expect(rotated.body.refreshToken).not.toBe(foreman.refreshToken);
      await t.http.get('/auth/me').set(bearer(rotated.body.accessToken)).expect(200);

      const replay = await t.http
        .post('/auth/refresh')
        .send({ refreshToken: foreman.refreshToken })
        .expect(401);
      expect(replay.body.error.code).toBe('TOKEN_REUSED');

      foreman = await loginForeman(t);
    });

    it('logout ends the session for the refresh token and the access token', async () => {
      // Warm the principal cache, so the check below proves logout evicts it.
      await t.http.get('/auth/me').set(bearer(foreman.accessToken)).expect(200);

      await t.http.post('/auth/logout').set(bearer(foreman.accessToken)).expect(204);

      await t.http.post('/auth/refresh').send({ refreshToken: foreman.refreshToken }).expect(401);
      const res = await t.http.get('/auth/me').set(bearer(foreman.accessToken)).expect(401);
      expect(res.body.error.code).toBe('TOKEN_INVALID');

      foreman = await loginForeman(t);
    });

    it('changing the password requires the current one and ends other sessions', async () => {
      const wrong = await t.http
        .post('/auth/password')
        .set(bearer(foreman.accessToken))
        .send({ currentPassword: 'wrong-password', newPassword: 'a-new-password-1' })
        .expect(400);
      expect(wrong.body.error.field).toBe('currentPassword');

      await t.http
        .post('/auth/password')
        .set(bearer(foreman.accessToken))
        .send({ currentPassword: foremanPassword, newPassword: 'a-new-password-1' })
        .expect(204);

      await t.http.get('/auth/me').set(bearer(foreman.accessToken)).expect(401);
      await t.http.post('/auth/refresh').send({ refreshToken: foreman.refreshToken }).expect(401);
    });
  });

  // Last: by now the login budget for this app instance is spent.
  it('throttles foreman login', async () => {
    const res = await t.http
      .post('/foreman/login')
      .send({ email: foremanEmail, password: foremanPassword })
      .expect(429);
    expect(res.body.error.code).toBe('RATE_LIMITED');
  });
});

function sha256(value: string): string {
  return createHash('sha256').update(value).digest('hex');
}
