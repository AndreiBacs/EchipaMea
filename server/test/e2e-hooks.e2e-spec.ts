import { WS_PATHS } from '../src/realtime/realtime-ticket.service';
import { createTestApp, type TestApp } from './support/app';
import { bearer, loginForeman, realtimeTicket, type ForemanSession } from './support/auth';
import { resetDb } from './support/db';
import { openSocket, type TestSocket } from './support/socket';

const DROP = '/__e2e/realtime/drop-foremen';

/**
 * The hooks the Flutter app's end-to-end suite uses to force failures. They
 * must not exist for anyone else: off by default, they answer like a route
 * that is not there.
 */
describe('e2e test hooks (e2e)', () => {
  describe('off (the default)', () => {
    let t: TestApp;
    let foreman: ForemanSession;

    beforeAll(async () => {
      t = await createTestApp();
      await resetDb(t.prisma);
      foreman = await loginForeman(t, 'demo');
    });

    afterAll(async () => {
      await t.close();
    });

    it('answers 404 NOT_FOUND, even to a signed-in foreman', async () => {
      const res = await t.http.post(DROP).set(bearer(foreman.accessToken));
      expect(res.status).toBe(404);
      expect(res.body.error.code).toBe('NOT_FOUND');
    });
  });

  describe('on', () => {
    let t: TestApp;
    let foreman: ForemanSession;
    let rival: ForemanSession;
    const sockets: TestSocket[] = [];

    beforeAll(async () => {
      t = await createTestApp({ E2E_TEST_HOOKS: true });
      await resetDb(t.prisma);
      foreman = await loginForeman(t, 'demo');
      rival = await loginForeman(t, 'rival');
    });

    afterEach(async () => {
      await Promise.all(sockets.splice(0).map((socket) => socket.close()));
    });

    afterAll(async () => {
      await t.close();
    });

    async function foremanSocket(accessToken: string): Promise<TestSocket> {
      const ticket = await realtimeTicket(t, accessToken);
      const socket = await openSocket(
        `${t.wsUrl}${WS_PATHS.foremanNotifications}?ticket=${encodeURIComponent(ticket)}`,
      );
      sockets.push(socket);
      await socket.next('connected');
      return socket;
    }

    it("closes the caller's company foreman sockets with 1001, as a network drop would", async () => {
      const socket = await foremanSocket(foreman.accessToken);

      const res = await t.http.post(DROP).set(bearer(foreman.accessToken));

      expect(res.status).toBe(200);
      expect(res.body).toEqual({ closed: 1 });
      expect((await socket.closed).code).toBe(1001);
    });

    it("never touches another company's sockets", async () => {
      const mine = await foremanSocket(foreman.accessToken);

      const res = await t.http.post(DROP).set(bearer(rival.accessToken));

      expect(res.body).toEqual({ closed: 0 });
      await mine.expectSilence('connected');
      expect(mine.ws.readyState).toBe(mine.ws.OPEN);
    });

    it('still needs a token', async () => {
      const res = await t.http.post(DROP);
      expect(res.status).toBe(401);
    });
  });
});
