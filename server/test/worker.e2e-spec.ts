import type { PagedNotificationsDto } from '../src/notifications/dto/notification.dto';
import type { ProjectDto } from '../src/projects/dto/project.dto';
import type {
  ArrivalsDto,
  LatestLocationsDto,
  LocationTrailDto,
} from '../src/telemetry/dto/telemetry.dto';
import type {
  LocationBatchResultDto,
  WorkerArrivalDto,
  WorkerProfileDto,
  WorkerProjectsDto,
} from '../src/worker/dto/worker.dto';
import { createTestApp, type TestApp } from './support/app';
import { bearer, loginForeman, workerSession } from './support/auth';
import { resetDb } from './support/db';
import {
  body,
  createProject,
  expectError,
  isoFromNow,
  phaseAt,
  uniqueName,
} from './support/domain-helpers';

/**
 * The worker-scoped endpoints (`/worker/*`) and the foreman's reads of what
 * they write (`/arrivals`, `/telemetry/*`).
 *
 * Seeded assignments: e1 is on p1 (in progress), e3 on p2 (planned), e2 only
 * on p3 (done). One foreman login and one worker session per employee, made in
 * `beforeAll` and reused -- login and ticket redemption are both throttled.
 */
describe('worker endpoints (e2e)', () => {
  let t: TestApp;
  let foremanToken: string;
  let foreman: { Authorization: string };
  let e1: { Authorization: string };
  let e2: { Authorization: string };
  let e3: { Authorization: string };

  beforeAll(async () => {
    t = await createTestApp();
    await resetDb(t.prisma);
    foremanToken = (await loginForeman(t)).accessToken;
    foreman = bearer(foremanToken);
    e1 = bearer((await workerSession(t, foremanToken, 'e1')).accessToken);
    e2 = bearer((await workerSession(t, foremanToken, 'e2')).accessToken);
    e3 = bearer((await workerSession(t, foremanToken, 'e3')).accessToken);
  });

  afterAll(async () => {
    await t.close();
  });

  async function projectIds(
    worker: { Authorization: string },
    query: Record<string, string> = {},
  ): Promise<string[]> {
    const res = await t.http.get('/worker/projects').query(query).set(worker).expect(200);
    return body<WorkerProjectsDto>(res).items.map((p) => p.id);
  }

  // -------------------------------------------------------------------------
  describe('GET /worker/me', () => {
    it('returns the signed-in employee, including the telemetry working window', async () => {
      const res = await t.http.get('/worker/me').set(e1).expect(200);
      expect(body<WorkerProfileDto>(res)).toEqual({
        employeeId: 'e1',
        name: 'Andrei D.',
        role: 'electrician',
        email: 'andrei@example.com',
        phone: '+40 721 000 111',
        workStartHour: 7,
        workEndHour: 16,
        workingDays: [1, 2, 3, 4, 5],
        latitude: 46.7729,
        longitude: 23.6243,
        companyId: 'demo-company',
        companyName: 'EchipaMea Demo SRL',
      });
    });

    it('refuses a foreman token, which has no employee to be "me"', async () => {
      expectError(await t.http.get('/worker/me').set(foreman), 403, 'FORBIDDEN');
    });
  });

  // -------------------------------------------------------------------------
  describe('GET /worker/projects', () => {
    it('lists only the projects assigned to the signed-in worker', async () => {
      expect(await projectIds(e1)).toEqual(['p1']);
      expect(await projectIds(e3)).toEqual(['p2']);

      const res = await t.http.get('/worker/projects').set(e1).expect(200);
      const list = body<WorkerProjectsDto>(res);
      expect(list.page).toEqual({ limit: 100, total: 1 });
      // The full project read shape, phases and instructions included.
      expect(list.items[0]?.phases.map((p) => p.id)).toEqual(['p1_phase_1', 'p1_phase_2']);
    });

    it("hides finished projects unless includeDone=true (e2's only job is done)", async () => {
      const hidden = await t.http.get('/worker/projects').set(e2).expect(200);
      expect(body<WorkerProjectsDto>(hidden)).toEqual({
        items: [],
        page: { limit: 100, total: 0 },
      });

      const shown = await t.http
        .get('/worker/projects')
        .query({ includeDone: 'true' })
        .set(e2)
        .expect(200);
      expect(body<WorkerProjectsDto>(shown).items.map((p) => [p.id, p.status])).toEqual([
        ['p3', 'done'],
      ]);
    });

    it('counts a live phase assignment, and stops counting it once the phase is deleted', async () => {
      // No project-level assignment at all: e2 is only on the phase.
      const project = await createProject(t, foremanToken, {
        clientId: 'c1',
        phases: [{ assignedEmployeeIds: ['e2'] }],
      });
      const phase = phaseAt(project, 0);

      expect(await projectIds(e2)).toEqual([project.id]);
      // In progress, then planned, then done: the new planned job precedes p3.
      expect(await projectIds(e2, { includeDone: 'true' })).toEqual([project.id, 'p3']);
      await t.http.get(`/worker/projects/${project.id}`).set(e2).expect(200);

      await t.http.delete(`/projects/${project.id}/phases/${phase.id}`).set(foreman).expect(204);

      expect(await projectIds(e2)).toEqual([]);
      expectError(await t.http.get(`/worker/projects/${project.id}`).set(e2), 404, 'NOT_FOUND');
    });

    it('orders in-progress work before planned work, whatever the names', async () => {
      // "AAA ..." sorts before p1's "Renovation ..." by name, but p1 is in
      // progress and this one is only planned.
      const planned = await createProject(t, foremanToken, {
        name: uniqueName('AAA Planned job'),
        assignedEmployeeIds: ['e1'],
        phases: [{}],
      });
      expect(await projectIds(e1)).toEqual(['p1', planned.id]);
    });
  });

  // -------------------------------------------------------------------------
  describe('GET /worker/projects/:projectId', () => {
    it('returns an assigned project with its phases and work instructions', async () => {
      const res = await t.http.get('/worker/projects/p1').set(e1).expect(200);
      const project = body<ProjectDto>(res);
      expect(project).toMatchObject({ id: 'p1', status: 'inProgress', clientId: 'c1' });
      expect(phaseAt(project, 0).workInstructions.map((i) => i.id)).toEqual(['p1_wi_1', 'p1_wi_2']);
    });

    it('answers 404, not 403, for a project that exists but is not assigned', async () => {
      // p2 is real and belongs to the same company. A 403 would confirm that,
      // so it must be indistinguishable from an id that was never issued.
      const notMine = await t.http.get('/worker/projects/p2').set(e1);
      const missing = await t.http.get('/worker/projects/no-such-project').set(e1);
      const otherTenant = await t.http.get('/worker/projects/rival_p1').set(e1);

      for (const res of [notMine, missing, otherTenant]) {
        expectError(res, 404, 'NOT_FOUND');
      }
    });
  });

  // -------------------------------------------------------------------------
  describe('POST /worker/arrivals', () => {
    async function arrive(
      worker: { Authorization: string },
      payload: { projectId: string; arrivedAt?: string },
    ): Promise<WorkerArrivalDto> {
      const res = await t.http.post('/worker/arrivals').set(worker).send(payload).expect(201);
      return body<WorkerArrivalDto>(res);
    }

    async function arrivals(query: Record<string, string>): Promise<ArrivalsDto> {
      const res = await t.http.get('/arrivals').query(query).set(foreman).expect(200);
      return body<ArrivalsDto>(res);
    }

    it('collapses repeat taps within 15 minutes and tells the foreman once', async () => {
      const first = await arrive(e1, { projectId: 'p1' });
      expect(first).toMatchObject({ projectId: 'p1', employeeId: 'e1', duplicate: false });

      const again = await arrive(e1, { projectId: 'p1' });
      expect(again).toEqual({ ...first, duplicate: true });

      const seen = await arrivals({ projectId: 'p1' });
      expect(seen.page.total).toBe(1);
      expect(seen.items).toEqual([
        {
          id: first.id,
          projectId: 'p1',
          projectName: 'Renovation - Main Street 15',
          employeeId: 'e1',
          employeeName: 'Andrei D.',
          arrivedAt: first.arrivedAt,
        },
      ]);

      // One stored notification for the one foreman, and none for the repeat.
      const res = await t.http
        .get('/notifications')
        .query({ kind: 'workerArrived' })
        .set(foreman)
        .expect(200);
      const notifications = body<PagedNotificationsDto>(res);
      expect(notifications.items).toHaveLength(1);
      expect(notifications.items[0]).toMatchObject({
        kind: 'workerArrived',
        projectId: 'p1',
        employeeId: 'e1',
        occurredAt: first.arrivedAt,
        readAt: null,
        payload: {
          projectId: 'p1',
          projectName: 'Renovation - Main Street 15',
          employeeId: 'e1',
          employeeName: 'Andrei D.',
        },
      });
      expect(notifications.unreadCount).toBeGreaterThanOrEqual(1);
    });

    it('records a new arrival once the previous one is more than 15 minutes old', async () => {
      // A phone that was briefly offline backdates its tap.
      const earlier = await arrive(e3, { projectId: 'p2', arrivedAt: isoFromNow(-40) });
      const now = await arrive(e3, { projectId: 'p2' });
      const repeat = await arrive(e3, { projectId: 'p2' });

      expect(earlier.duplicate).toBe(false);
      expect(now).toMatchObject({ duplicate: false });
      expect(now.id).not.toBe(earlier.id);
      expect(repeat).toMatchObject({ id: now.id, duplicate: true });

      // Newest first.
      const seen = await arrivals({ projectId: 'p2' });
      expect(seen.items.map((a) => a.id)).toEqual([now.id, earlier.id]);
      expect(seen.page.total).toBe(2);

      const today = now.arrivedAt.slice(0, 10);
      const byDay = await arrivals({ employeeId: 'e3', day: today });
      expect(byDay.items.map((a) => a.id)).toContain(now.id);
      expect((await arrivals({ projectId: 'p2', day: '2020-01-01' })).page.total).toBe(0);
      expect((await arrivals({ projectId: 'p2', employeeId: 'e1' })).page.total).toBe(0);
    });

    // Regression: the 15-minute dedupe window used to be bounded below only,
    // so a backdated tap (the offline case `arrivedAt` exists for) was folded
    // into a *later* arrival however far apart they were.
    it('does not fold a backdated tap into a later arrival 40 minutes away', async () => {
      // e2 is still assigned to p3 at project level, done or not.
      const later = await arrive(e2, { projectId: 'p3' });
      expect(later.duplicate).toBe(false);

      const backdated = await arrive(e2, { projectId: 'p3', arrivedAt: isoFromNow(-40) });
      expect(backdated.duplicate).toBe(false);
      expect(backdated.id).not.toBe(later.id);
    });

    it('refuses a project the worker is not on, a foreman token and a missing projectId', async () => {
      expectError(
        await t.http.post('/worker/arrivals').set(e1).send({ projectId: 'p2' }),
        404,
        'NOT_FOUND',
      );
      expectError(
        await t.http.post('/worker/arrivals').set(foreman).send({ projectId: 'p1' }),
        403,
        'FORBIDDEN',
      );
      expectError(
        await t.http.post('/worker/arrivals').set(e1).send({}),
        400,
        'VALIDATION_FAILED',
        'projectId',
      );
      expect((await arrivals({ projectId: 'p2', employeeId: 'e1' })).page.total).toBe(0);
    });
  });

  // -------------------------------------------------------------------------
  describe('POST /worker/locations', () => {
    function sample(capturedAt: string, latitude = 46.77, longitude = 23.62) {
      return { latitude, longitude, accuracyMeters: 8, capturedAt };
    }

    async function upload(
      worker: { Authorization: string },
      samples: unknown[],
    ): Promise<LocationBatchResultDto> {
      const res = await t.http.post('/worker/locations').set(worker).send({ samples }).expect(200);
      return body<LocationBatchResultDto>(res);
    }

    it('is safe to retry: a resent batch and in-batch repeats are not stored twice', async () => {
      const t1 = isoFromNow(-30);
      const t2 = isoFromNow(-20);
      // Dart on mobile sends six fractional digits; the instant is the same
      // millisecond either way.
      const t3 = isoFromNow(-10).replace(/Z$/, '456Z');
      const batch = [sample(t1), sample(t2), sample(t2, 46.78, 23.63), sample(t3)];

      expect(await upload(e1, batch)).toEqual({ accepted: 3, duplicates: 1 });
      // The client never saw the first response and flushes its outbox again.
      expect(await upload(e1, batch)).toEqual({ accepted: 0, duplicates: 4 });

      const stored = await t.prisma.workerLocationSample.count({
        where: { employeeId: 'e1', capturedAt: { gte: new Date(t1), lte: new Date(t3) } },
      });
      expect(stored).toBe(3);
    });

    it('rejects a batch over the 500-sample cap outright rather than truncating it', async () => {
      const base = Date.now() - 2 * 24 * 3600_000;
      const batchOf = (size: number, offsetMs: number) =>
        Array.from({ length: size }, (_, i) =>
          sample(new Date(base + offsetMs + i * 1000).toISOString()),
        );

      // Exactly at the cap is fine...
      expect(await upload(e2, batchOf(500, 0))).toEqual({ accepted: 500, duplicates: 0 });

      // ...one over is refused whole, and none of it is written.
      const before = await t.prisma.workerLocationSample.count({ where: { employeeId: 'e2' } });
      expectError(
        await t.http
          .post('/worker/locations')
          .set(e2)
          .send({ samples: batchOf(501, 3600_000) }),
        400,
        'VALIDATION_FAILED',
        'samples',
      );
      expect(await t.prisma.workerLocationSample.count({ where: { employeeId: 'e2' } })).toBe(
        before,
      );

      expectError(
        await t.http.post('/worker/locations').set(e2).send({ samples: [] }),
        400,
        'VALIDATION_FAILED',
        'samples',
      );
    });

    it('validates each sample, and is for worker tokens only', async () => {
      expectError(
        await t.http
          .post('/worker/locations')
          .set(e1)
          .send({ samples: [sample(isoFromNow(-1), 91)] }),
        400,
        'VALIDATION_FAILED',
        'samples.0.latitude',
      );
      expectError(
        await t.http
          .post('/worker/locations')
          .set(e1)
          .send({ samples: [sample('yesterday')] }),
        400,
        'VALIDATION_FAILED',
        'samples.0.capturedAt',
      );
      expectError(
        await t.http
          .post('/worker/locations')
          .set(foreman)
          .send({ samples: [sample(isoFromNow(-1))] }),
        403,
        'FORBIDDEN',
      );
    });
  });

  // -------------------------------------------------------------------------
  describe('telemetry reads (foreman)', () => {
    async function latestFor(employeeId: string) {
      const res = await t.http.get('/telemetry/latest').set(foreman).expect(200);
      return body<LatestLocationsDto>(res).items.find((item) => item.employeeId === employeeId);
    }

    async function trail(query: Record<string, string>): Promise<LocationTrailDto> {
      const res = await t.http.get('/telemetry/locations').query(query).set(foreman).expect(200);
      return body<LocationTrailDto>(res);
    }

    it('orders last-seen by receivedAt, so a clock set in the future cannot pin itself on top', async () => {
      const twoDays = 2 * 24 * 3600;
      const future = isoFromNow(twoDays / 60);
      await t.http
        .post('/worker/locations')
        .set(e3)
        .send({ samples: [{ latitude: 46.1, longitude: 23.1, capturedAt: future }] })
        .expect(200);

      // While it is the newest fix received, it is shown -- with the skew.
      const skewed = await latestFor('e3');
      expect(skewed).toMatchObject({ capturedAt: future, employeeName: 'Ioana R.' });
      expect(skewed?.clockSkewSeconds).toBeGreaterThan(twoDays - 120);
      expect(skewed?.clockSkewSeconds).toBeLessThan(twoDays + 120);

      // A healthy fix received afterwards wins, although its capturedAt is
      // two days "older".
      const now = new Date().toISOString();
      await t.http
        .post('/worker/locations')
        .set(e3)
        .send({ samples: [{ latitude: 46.2, longitude: 23.2, capturedAt: now }] })
        .expect(200);

      const latest = await latestFor('e3');
      expect(latest).toMatchObject({ capturedAt: now, latitude: 46.2, longitude: 23.2 });
      expect(Math.abs(latest?.clockSkewSeconds ?? Infinity)).toBeLessThan(60);
      expect(latest?.ageSeconds).toBeLessThan(60);
      expect(Date.parse(latest?.receivedAt ?? '')).toBeGreaterThan(
        Date.parse(skewed?.receivedAt ?? ''),
      );
    });

    it('filters the trail by employee, window and limit, newest capture first', async () => {
      const captured = [-300, -240, -180].map((minutes) => isoFromNow(minutes));
      await t.http
        .post('/worker/locations')
        .set(e1)
        .send({
          samples: captured.map((capturedAt) => ({ latitude: 46.3, longitude: 23.3, capturedAt })),
        })
        .expect(200);
      const window = { from: isoFromNow(-360), to: isoFromNow(-120) };

      const all = await trail({ employeeId: 'e1', ...window });
      expect(all.page.total).toBe(3);
      expect(all.items.map((s) => s.capturedAt)).toEqual([...captured].reverse());
      expect(all.items.every((s) => s.employeeId === 'e1' && s.employeeName === 'Andrei D.')).toBe(
        true,
      );

      const limited = await trail({ employeeId: 'e1', ...window, limit: '1' });
      expect(limited.items.map((s) => s.capturedAt)).toEqual([captured[2]]);
      expect(limited.page).toEqual({ limit: 1, total: 3 });

      const narrow = await trail({
        employeeId: 'e1',
        from: isoFromNow(-250),
        to: isoFromNow(-230),
      });
      expect(narrow.items.map((s) => s.capturedAt)).toEqual([captured[1]]);

      expect((await trail({ employeeId: 'e2', ...window })).page.total).toBe(0);

      expectError(
        await t.http.get('/telemetry/locations').query({ limit: '0' }).set(foreman),
        400,
        'VALIDATION_FAILED',
        'limit',
      );
    });

    it('defaults the trail to the last 24 hours instead of the whole history', async () => {
      const old = isoFromNow(-30 * 60);
      await t.http
        .post('/worker/locations')
        .set(e3)
        .send({ samples: [{ latitude: 46.4, longitude: 23.4, capturedAt: old }] })
        .expect(200);

      const unbounded = await trail({ employeeId: 'e3' });
      expect(Date.parse(unbounded.to) - Date.parse(unbounded.from)).toBe(24 * 3600_000);
      expect(unbounded.items.map((s) => s.capturedAt)).not.toContain(old);

      const widened = await trail({ employeeId: 'e3', from: isoFromNow(-31 * 60) });
      expect(widened.items.map((s) => s.capturedAt)).toContain(old);
    });

    it('is foreman-only: a worker token cannot read positions or arrivals', async () => {
      for (const path of ['/telemetry/latest', '/telemetry/locations', '/arrivals']) {
        expectError(await t.http.get(path).set(e1), 403, 'FORBIDDEN');
      }
    });
  });
});
