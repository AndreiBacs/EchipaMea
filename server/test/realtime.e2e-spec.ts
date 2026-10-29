import { createHash } from 'crypto';
import { WS_PATHS } from '../src/realtime/realtime-ticket.service';
import { createTestApp, type TestApp } from './support/app';
import {
  bearer,
  loginForeman,
  realtimeTicket,
  workerSession,
  type ForemanSession,
  type WorkerSession,
} from './support/auth';
import { resetDb } from './support/db';
import { dartTimestamp, jpeg, m4a, postReport, type ReportUpload } from './support/report-upload';
import { openSocket, type Frame, type TestSocket } from './support/socket';

const TELEMETRY = WS_PATHS.workerTelemetry;
const NOTIFICATIONS = WS_PATHS.foremanNotifications;

interface TicketDto {
  ticket: string;
  expiresAt: string;
  expiresInSeconds: number;
  channels: { workerTelemetry: string; foremanNotifications: string };
}

/**
 * Both WebSocket channels, end to end, over the real `TypeFieldWsAdapter`.
 *
 * The contract under test is docs/websockets-asyncapi-draft.yaml: raw RFC-6455
 * with flat `{"type": ...}` frames; credentials only as a single-use `?ticket=`
 * or an `Authorization: Bearer` header; a failed handshake is an `error` frame
 * followed by a 4401/4403 close; and once open, a bad frame is answered with an
 * `error` frame and never a close, because both Flutter sockets listen with
 * `cancelOnError: true` and have no reconnect.
 *
 * Every socket a test opens is closed in `afterEach`.
 */
describe('realtime (e2e)', () => {
  let t: TestApp;
  let foreman: ForemanSession;
  let rival: ForemanSession;
  let worker: WorkerSession;
  const sockets: TestSocket[] = [];

  beforeAll(async () => {
    t = await createTestApp();
    await resetDb(t.prisma);
    foreman = await loginForeman(t, 'demo');
    rival = await loginForeman(t, 'rival');
    worker = await workerSession(t, foreman.accessToken, 'e1');
  });

  afterEach(async () => {
    await Promise.all(sockets.splice(0).map((socket) => socket.close()));
  });

  afterAll(async () => {
    await t.close();
  });

  async function open(
    path: string,
    query = '',
    headers?: Record<string, string>,
  ): Promise<TestSocket> {
    const socket = await openSocket(`${t.wsUrl}${path}${query}`, { headers });
    sockets.push(socket);
    return socket;
  }

  /** Opens a socket the way the app does: fetch a ticket, pass it as `?ticket=`. */
  async function withTicket(path: string, accessToken: string): Promise<TestSocket> {
    const ticket = await realtimeTicket(t, accessToken);
    return open(path, `?ticket=${encodeURIComponent(ticket)}`);
  }

  /** `withTicket`, then waits for the `connected` frame. */
  async function connected(path: string, accessToken: string): Promise<TestSocket> {
    const socket = await withTicket(path, accessToken);
    await socket.next('connected');
    return socket;
  }

  /**
   * A refused handshake: the first frame is an `error` with `code`, then the
   * server closes with `closeCode`, and nothing else -- `connected` above all --
   * was ever sent.
   */
  async function expectRefused(socket: TestSocket, code: string, closeCode: number) {
    const first = await socket.next();
    expect(first).toMatchObject({ type: 'error', code, message: expect.any(String) });
    expect((await socket.closed).code).toBe(closeCode);
    await expect(socket.next(undefined, 100)).rejects.toThrow(/No any frame within/);
    return first;
  }

  function sha256(value: string): string {
    return createHash('sha256').update(value).digest('hex');
  }

  /** A report from e1 on p1_phase_1, as the app fills it in. */
  function report(overrides: Partial<ReportUpload> = {}): ReportUpload {
    return {
      projectId: 'p1',
      projectName: 'Renovation - Main Street 15',
      phaseId: 'p1_phase_1',
      phaseName: 'Demolition',
      employeeId: 'e1',
      employeeName: 'Andrei D.',
      description: 'Demolition finished on the ground floor.',
      submittedAt: dartTimestamp(),
      photos: [],
      ...overrides,
    };
  }

  /**
   * The `worker_report_submitted` frame older app builds sent on the foreman
   * channel right after an upload, for the same report.
   */
  function noticeFor(upload: ReportUpload, overrides: Record<string, unknown> = {}) {
    return {
      type: 'worker_report_submitted',
      projectId: upload.projectId,
      projectName: upload.projectName,
      phaseId: upload.phaseId,
      phaseName: upload.phaseName,
      employeeId: upload.employeeId,
      employeeName: upload.employeeName,
      description: upload.description,
      photoCount: upload.photos?.length ?? 0,
      hasVoiceMemo: upload.voiceMemo !== undefined,
      submittedAt: upload.submittedAt,
      ...overrides,
    };
  }

  /** The frame `worker_telemetry_coordinator.dart` writes every ~30 minutes. */
  function locationFrame(overrides: Record<string, unknown> = {}) {
    return {
      type: 'worker_location',
      employeeId: 'e1',
      employeeName: 'Andrei D.',
      latitude: 46.7729,
      longitude: 23.6243,
      accuracyMeters: 12.5,
      capturedAt: dartTimestamp(),
      ...overrides,
    };
  }

  describe('tickets', () => {
    it('POST /realtime/tickets mints a 60-second ticket, stores only its hash, and names the channels', async () => {
      const res = await t.http
        .post('/realtime/tickets')
        .set(bearer(foreman.accessToken))
        .expect(201);
      const body = res.body as TicketDto;

      expect(body).toEqual({
        ticket: expect.stringMatching(/^rtt_[A-Za-z0-9_-]{20,}$/),
        expiresAt: expect.any(String),
        expiresInSeconds: 60,
        channels: {
          workerTelemetry: '/ws/worker-telemetry',
          foremanNotifications: '/ws/foreman-notifications',
        },
      });
      const ttlMs = new Date(body.expiresAt).getTime() - Date.now();
      expect(ttlMs).toBeGreaterThan(50_000);
      expect(ttlMs).toBeLessThanOrEqual(60_000);

      expect(await t.prisma.realtimeTicket.count({ where: { ticketHash: body.ticket } })).toBe(0);
      const row = await t.prisma.realtimeTicket.findUniqueOrThrow({
        where: { ticketHash: sha256(body.ticket) },
      });
      expect(row).toMatchObject({
        companyId: 'demo-company',
        role: 'foreman',
        userId: 'foreman_local',
        employeeId: null,
        usedAt: null,
      });
    });

    it('a worker ticket carries the employee', async () => {
      const ticket = await realtimeTicket(t, worker.accessToken);
      const row = await t.prisma.realtimeTicket.findUniqueOrThrow({
        where: { ticketHash: sha256(ticket) },
      });
      expect(row).toMatchObject({ role: 'worker', employeeId: 'e1', userId: null });
    });

    it('minting a ticket requires a token', async () => {
      const res = await t.http.post('/realtime/tickets').expect(401);
      expect((res.body as { error: { code: string } }).error.code).toBe('UNAUTHENTICATED');
    });

    it('is single-use: a second handshake with the same ticket is closed with 4401', async () => {
      const ticket = await realtimeTicket(t, foreman.accessToken);
      const first = await open(NOTIFICATIONS, `?ticket=${encodeURIComponent(ticket)}`);
      await first.next('connected');

      const replay = await open(NOTIFICATIONS, `?ticket=${encodeURIComponent(ticket)}`);

      await expectRefused(replay, 'TICKET_ALREADY_REDEEMED', 4401);
    });

    it('refuses an expired ticket with 4401', async () => {
      const ticket = await realtimeTicket(t, worker.accessToken);
      await t.prisma.realtimeTicket.updateMany({
        where: { ticketHash: sha256(ticket) },
        data: { expiresAt: new Date(Date.now() - 1000) },
      });

      const socket = await open(TELEMETRY, `?ticket=${encodeURIComponent(ticket)}`);

      await expectRefused(socket, 'TICKET_EXPIRED', 4401);
    });

    it('refuses an unknown ticket with 4401', async () => {
      const socket = await open(NOTIFICATIONS, '?ticket=rtt_never-issued');
      await expectRefused(socket, 'TICKET_NOT_FOUND', 4401);
    });
  });

  describe('handshake authentication', () => {
    it.each([TELEMETRY, NOTIFICATIONS])(
      '%s: no credentials is an error frame and 4401, never connected',
      async (path) => {
        const socket = await open(path);
        await expectRefused(socket, 'UNAUTHENTICATED', 4401);
      },
    );

    it.each(['token', 'access_token'])(
      'refuses an access token in ?%s= and points at /realtime/tickets',
      async (param) => {
        const socket = await open(NOTIFICATIONS, `?${param}=${foreman.accessToken}`);
        const error = await expectRefused(socket, 'UNAUTHENTICATED', 4401);
        expect(error.message).toContain('/realtime/tickets');
      },
    );

    it('accepts an Authorization: Bearer header on the handshake', async () => {
      const socket = await open(NOTIFICATIONS, '', bearer(foreman.accessToken));

      expect(await socket.next()).toEqual({
        type: 'connected',
        channel: 'foremanNotifications',
        role: 'foreman',
        serverTime: expect.any(String),
        heartbeatIntervalMs: 30_000,
      });
    });

    it('refuses an invalid bearer token with 4401', async () => {
      const socket = await open(TELEMETRY, '', bearer('not-a-jwt'));
      await expectRefused(socket, 'TOKEN_INVALID', 4401);
    });
  });

  describe('worker telemetry channel', () => {
    it('admits workers only: a foreman ticket gets FORBIDDEN and 4403', async () => {
      const socket = await withTicket(TELEMETRY, foreman.accessToken);
      await expectRefused(socket, 'FORBIDDEN', 4403);
    });

    it("stores a location fix against the token's employee, whatever the frame claims", async () => {
      const socket = await withTicket(TELEMETRY, worker.accessToken);
      expect(await socket.next('connected')).toMatchObject({
        channel: 'workerTelemetry',
        role: 'worker',
      });
      const before = await t.prisma.workerLocationSample.count({ where: { employeeId: 'e1' } });
      const frame = locationFrame({ employeeId: 'e2', latitude: 46.7701, longitude: 23.5899 });

      socket.send(frame);

      const ack = await socket.next('ack');
      expect(ack).toEqual({ type: 'ack', of: 'worker_location', receivedAt: expect.any(String) });
      const samples = await t.prisma.workerLocationSample.findMany({
        where: { employeeId: 'e1' },
        orderBy: { id: 'desc' },
      });
      expect(samples).toHaveLength(before + 1);
      expect(samples[0]).toMatchObject({
        companyId: 'demo-company',
        latitude: 46.7701,
        longitude: 23.5899,
        accuracyMeters: 12.5,
        capturedAt: new Date(frame.capturedAt),
      });
      expect(await t.prisma.workerLocationSample.count({ where: { employeeId: 'e2' } })).toBe(0);
    });

    it('answers a frame sent before the handshake has settled', async () => {
      // The app writes as soon as the socket opens; the ticket is still being
      // redeemed against the database at that point.
      const socket = await withTicket(TELEMETRY, worker.accessToken);
      socket.send(locationFrame());

      expect(await socket.next('ack')).toMatchObject({ of: 'worker_location' });
    });

    it('rejects an invalid fix with VALIDATION_FAILED and keeps the socket open', async () => {
      const socket = await connected(TELEMETRY, worker.accessToken);

      socket.send(locationFrame({ latitude: 123 }));
      expect(await socket.next('error')).toMatchObject({ code: 'VALIDATION_FAILED' });

      socket.send(locationFrame());
      expect(await socket.next('ack')).toMatchObject({ of: 'worker_location' });
    });

    it('does not accept report notices here', async () => {
      const socket = await connected(TELEMETRY, worker.accessToken);

      socket.send(noticeFor(report()));

      expect(await socket.next('error')).toMatchObject({ code: 'UNKNOWN_MESSAGE_TYPE' });
    });
  });

  describe('foreman notification channel', () => {
    it('pushes worker_report_submitted to the company foremen on upload, and to nobody else', async () => {
      const demo = await connected(NOTIFICATIONS, foreman.accessToken);
      const other = await connected(NOTIFICATIONS, rival.accessToken);
      const workerSocket = await withTicket(NOTIFICATIONS, worker.accessToken);
      expect(await workerSocket.next('connected')).toMatchObject({
        channel: 'foremanNotifications',
        role: 'worker',
      });
      const upload = report({
        employeeId: 'e2',
        photos: [{ filename: 'IMG_0001.jpg', bytes: jpeg('realtime-push') }],
        voiceMemo: { filename: 'memo.m4a', bytes: m4a('realtime-push') },
      });

      await postReport(t, worker.accessToken, upload).expect(201);

      expect(await demo.next('worker_report_submitted')).toEqual({
        type: 'worker_report_submitted',
        projectId: 'p1',
        projectName: 'Renovation - Main Street 15',
        phaseId: 'p1_phase_1',
        phaseName: 'Demolition',
        employeeId: 'e1',
        employeeName: 'Andrei D.',
        description: upload.description,
        photoCount: 1,
        hasVoiceMemo: true,
        // Verbatim, six fractional digits and all.
        submittedAt: upload.submittedAt,
      });
      await other.expectSilence('worker_report_submitted');
      await workerSocket.expectSilence('worker_report_submitted', 100);
    });

    it("acks the worker's one-shot notice for an uploaded report as a duplicate, and does not re-broadcast", async () => {
      const demo = await connected(NOTIFICATIONS, foreman.accessToken);
      const upload = report();
      await postReport(t, worker.accessToken, upload).expect(201);
      await demo.next('worker_report_submitted');
      const notificationsBefore = await t.prisma.notification.count();

      const workerSocket = await connected(NOTIFICATIONS, worker.accessToken);
      // `employeeId` in the frame is overridden by the token, so a wrong one
      // still resolves to e1's report.
      workerSocket.send(noticeFor(upload, { employeeId: 'e2' }));

      expect(await workerSocket.next('ack')).toEqual({
        type: 'ack',
        of: 'worker_report_submitted',
        receivedAt: expect.any(String),
        duplicate: true,
      });
      await demo.expectSilence('worker_report_submitted');
      expect(await t.prisma.notification.count()).toBe(notificationsBefore);
    });

    it('answers the old connect-send-close notice even when it beats the handshake', async () => {
      const upload = report();
      await postReport(t, worker.accessToken, upload).expect(201);

      const workerSocket = await withTicket(NOTIFICATIONS, worker.accessToken);
      workerSocket.send(noticeFor(upload));

      expect(await workerSocket.next('ack')).toMatchObject({
        of: 'worker_report_submitted',
        duplicate: true,
      });
    });

    it('a notice with no matching upload still reaches the foremen, as the token employee', async () => {
      const demo = await connected(NOTIFICATIONS, foreman.accessToken);
      const other = await connected(NOTIFICATIONS, rival.accessToken);
      const upload = report({ description: 'Upload response was lost.' });
      const notificationsBefore = await t.prisma.notification.count({
        where: { recipientUserId: 'foreman_local' },
      });

      const workerSocket = await connected(NOTIFICATIONS, worker.accessToken);
      workerSocket.send(noticeFor(upload, { employeeId: 'e2', photoCount: 2 }));

      expect(await workerSocket.next('ack')).toMatchObject({
        of: 'worker_report_submitted',
        duplicate: false,
      });
      expect(await demo.next('worker_report_submitted')).toMatchObject({
        projectId: 'p1',
        phaseId: 'p1_phase_1',
        employeeId: 'e1',
        photoCount: 2,
        submittedAt: upload.submittedAt,
      });
      await other.expectSilence('worker_report_submitted');
      expect(
        await t.prisma.notification.count({ where: { recipientUserId: 'foreman_local' } }),
      ).toBe(notificationsBefore + 1);
      // A notice records a notification, never a report.
      expect(
        await t.prisma.workerReport.count({ where: { submittedAtRaw: upload.submittedAt } }),
      ).toBe(0);
    });

    // Regression: a notice with no matching upload leaves only notifications
    // behind, and the dedupe used to look for a report only -- so the same
    // notice twice meant two events and two notifications per foreman.
    it('dedupes a repeated notice that has no matching upload', async () => {
      const demo = await connected(NOTIFICATIONS, foreman.accessToken);
      const upload = report({ description: 'Sent twice.' });
      const workerSocket = await connected(NOTIFICATIONS, worker.accessToken);

      workerSocket.send(noticeFor(upload));
      expect(await workerSocket.next('ack')).toMatchObject({ duplicate: false });
      await demo.next('worker_report_submitted');
      const notificationsAfterFirst = await t.prisma.notification.count();

      workerSocket.send(noticeFor(upload));
      expect(await workerSocket.next('ack')).toMatchObject({ duplicate: true });
      await demo.expectSilence('worker_report_submitted');
      expect(await t.prisma.notification.count()).toBe(notificationsAfterFirst);
    });

    it("a rival worker's notice naming this company's phase reaches no foreman here", async () => {
      const demo = await connected(NOTIFICATIONS, foreman.accessToken);
      const rivalWorker = await workerSession(t, rival.accessToken, 'rival_e1');
      const rivalSocket = await connected(NOTIFICATIONS, rivalWorker.accessToken);
      const notificationsBefore = await t.prisma.notification.count();

      rivalSocket.send(noticeFor(report({ employeeId: 'rival_e1' })));

      await rivalSocket.next();
      await demo.expectSilence('worker_report_submitted');
      expect(await t.prisma.notification.count()).toBe(notificationsBefore);
    });

    // Regression: a notice for an unknown phase was dropped but acked as
    // `duplicate: true`, telling the device its notice had landed.
    it('answers a notice for an unknown phase with NOT_FOUND, not a duplicate ack', async () => {
      const workerSocket = await connected(NOTIFICATIONS, worker.accessToken);

      workerSocket.send(noticeFor(report({ phaseId: 'no_such_phase' })));

      expect(await workerSocket.next()).toMatchObject({ type: 'error', code: 'NOT_FOUND' });
    });

    it('rejects an invalid notice with VALIDATION_FAILED and keeps the socket open', async () => {
      const workerSocket = await connected(NOTIFICATIONS, worker.accessToken);
      const upload = report();

      workerSocket.send(noticeFor(upload, { phaseId: '' }));
      expect(await workerSocket.next('error')).toMatchObject({ code: 'VALIDATION_FAILED' });

      await postReport(t, worker.accessToken, upload).expect(201);
      workerSocket.send(noticeFor(upload));
      expect(await workerSocket.next('ack')).toMatchObject({ duplicate: true });
    });
  });

  describe('robustness: a bad frame is an error frame, never a close', () => {
    it('foreman socket: malformed, untyped, unknown and forbidden frames, then still delivering', async () => {
      const demo = await connected(NOTIFICATIONS, foreman.accessToken);
      const notificationsBefore = await t.prisma.notification.count();

      const answers: Frame[] = [];
      for (const frame of [
        'not json',
        '[1, 2, 3]',
        { hello: 'no type' },
        { type: 'worker_location', latitude: 1, longitude: 2 },
        noticeFor(report()),
      ]) {
        demo.send(frame);
        answers.push(await demo.next('error'));
      }

      expect(answers.map((frame) => frame.code)).toEqual([
        'MALFORMED_FRAME',
        'MALFORMED_FRAME',
        'MALFORMED_FRAME',
        'UNKNOWN_MESSAGE_TYPE',
        'SEND_NOT_ALLOWED',
      ]);
      // The refused notice recorded nothing.
      expect(await t.prisma.notification.count()).toBe(notificationsBefore);

      // Still open, and still the foreman's feed.
      const upload = report();
      await postReport(t, worker.accessToken, upload).expect(201);
      expect(await demo.next('worker_report_submitted')).toMatchObject({
        submittedAt: upload.submittedAt,
      });
    });

    it('telemetry socket: a malformed frame, then a valid fix is still acked', async () => {
      const socket = await connected(TELEMETRY, worker.accessToken);

      socket.send('not json');
      expect(await socket.next('error')).toMatchObject({ code: 'MALFORMED_FRAME' });
      socket.send({ type: 'worker_lunch_break' });
      expect(await socket.next('error')).toMatchObject({ code: 'UNKNOWN_MESSAGE_TYPE' });

      socket.send(locationFrame());
      expect(await socket.next('ack')).toMatchObject({ of: 'worker_location' });
    });
  });
});
