import { RIVAL_FOREMAN_EMAIL, defaultSeedCredentials } from '../../src/common/prisma/demo-seed';
import type { TestApp } from './app';

export interface ForemanSession {
  accessToken: string;
  refreshToken: string;
  user: { id: string; email: string; role: string; companyId: string; fullName: string };
}

export interface WorkerSession {
  accessToken: string;
  refreshToken: string;
  worker: { employeeId: string; employeeName: string; role: string; companyId: string };
}

export function bearer(token: string): { Authorization: string } {
  return { Authorization: `Bearer ${token}` };
}

/**
 * Logs in a seeded foreman. `POST /foreman/login` is throttled to 5 a minute
 * per client, so suites should log in once per role in `beforeAll` and reuse
 * the session rather than calling this per test.
 */
export async function loginForeman(
  t: TestApp,
  who: 'demo' | 'rival' = 'demo',
): Promise<ForemanSession> {
  const { foremanEmail, foremanPassword } = defaultSeedCredentials();
  const res = await t.http
    .post('/foreman/login')
    .send({ email: who === 'demo' ? foremanEmail : RIVAL_FOREMAN_EMAIL, password: foremanPassword })
    .expect(200);
  return res.body as ForemanSession;
}

/** Mints a QR login ticket as the foreman and redeems it, as the phone would. */
export async function workerSession(
  t: TestApp,
  foremanToken: string,
  employeeId: string,
): Promise<WorkerSession> {
  const ticket = await t.http
    .post(`/employees/${employeeId}/login-ticket`)
    .set(bearer(foremanToken))
    .expect(201);
  const res = await t.http
    .post('/worker/login-tickets/redeem')
    .send({ ticketId: (ticket.body as { ticketId: string }).ticketId })
    .expect(200);
  return res.body as WorkerSession;
}

/** A single-use ticket for one WebSocket handshake. */
export async function realtimeTicket(t: TestApp, token: string): Promise<string> {
  const res = await t.http.post('/realtime/tickets').set(bearer(token)).expect(201);
  return (res.body as { ticket: string }).ticket;
}
