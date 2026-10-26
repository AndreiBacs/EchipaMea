import { Prisma } from '@prisma/client';
import type { Response } from 'supertest';
import { DEMO_COMPANY_ID, OTHER_COMPANY_ID } from '../src/common/prisma/demo-seed';
import { PrismaService } from '../src/common/prisma/prisma.service';
import { createTestApp, type TestApp } from './support/app';
import {
  bearer,
  loginForeman,
  workerSession,
  type ForemanSession,
  type WorkerSession,
} from './support/auth';
import { AppModule } from '../src/app.module';
import { resetDb } from './support/db';
import {
  declaredRoutes,
  fillPathParams,
  requestRoute,
  type HttpMethod,
  type RouteInfo,
} from './support/routes';

/**
 * Cross-tenant isolation, probed end to end with a second seeded company.
 *
 * Services scope every query by the principal's `companyId`, and nothing at
 * runtime enforces that they do -- `tenant-guard.extension.ts` names this file
 * as "the real gate". So every probe below aims at a row that really exists in
 * the other tenant: a 404 for an id that was never there would prove nothing.
 *
 * The expected answer for another tenant's id is 404, the same as for an id
 * that does not exist. 403 would be safer than 200 but still confirms the id is
 * real, which turns any endpoint into an enumeration oracle.
 *
 * Order matters in one place: the rival's attempts run first and the
 * "mutations do not cross" checks run last, against a snapshot of every demo
 * row taken at the end of `beforeAll`.
 */

/** A day both p1_phase_1 (13-16 Apr) and p2_phase_1 (14-15 Apr) cover. */
const DAY = '2026-04-14';

const DEMO_SEED_IDS = [
  DEMO_COMPANY_ID,
  'foreman_local',
  'c1',
  'c2',
  'c3',
  'e1',
  'e2',
  'e3',
  'p1',
  'p2',
  'p3',
  'p1_phase_1',
  'p1_phase_2',
  'p2_phase_1',
  'p3_phase_1',
  'p1_wi_1',
  'p1_wi_2',
];

const RIVAL_SEED_IDS = [OTHER_COMPANY_ID, 'rival_foreman', 'rival_c1', 'rival_e1', 'rival_p1'];

/** PNG magic bytes, so the sniffer accepts it, plus a suffix unique to this suite. */
const PNG = Buffer.concat([
  Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
  Buffer.from('tenancy-e2e'),
]);

/**
 * One request. `:name` in the path is filled at run time from ids created in
 * `beforeAll` (`:demoMediaId`, `:rivalPhaseId`, ...), since Jest builds these
 * tables before any of them exist.
 */
interface Probe {
  method: HttpMethod;
  path: string;
  body?: Record<string, unknown>;
}

const label = (probe: Probe): string => `${probe.method} ${probe.path}`;

/** Demo-company resources the rival foreman must not be able to tell exist. */
const RIVAL_FOREMAN_NOT_FOUND: Probe[] = [
  { method: 'GET', path: '/clients/c1' },
  { method: 'PATCH', path: '/clients/c1', body: { name: 'Taken over' } },
  { method: 'DELETE', path: '/clients/c1' },
  { method: 'GET', path: '/employees/e1' },
  { method: 'PATCH', path: '/employees/e1', body: { name: 'Taken over', isActive: false } },
  { method: 'DELETE', path: '/employees/e1' },
  { method: 'POST', path: '/employees/e1/login-ticket' },
  { method: 'GET', path: '/projects/p1' },
  { method: 'PATCH', path: '/projects/p1', body: { name: 'Taken over' } },
  { method: 'POST', path: '/projects/p1/done' },
  { method: 'POST', path: '/projects/p1/reopen' },
  { method: 'DELETE', path: '/projects/p1' },
  { method: 'GET', path: '/projects/p1/phases' },
  {
    method: 'POST',
    path: '/projects/p1/phases',
    body: { name: 'Planted', startDate: DAY, endDate: DAY },
  },
  {
    method: 'POST',
    path: '/projects/p1/phases/reorder',
    body: { phaseIds: ['p1_phase_2', 'p1_phase_1'] },
  },
  { method: 'GET', path: '/projects/p1/phases/p1_phase_1' },
  { method: 'PATCH', path: '/projects/p1/phases/p1_phase_1', body: { name: 'Taken over' } },
  { method: 'DELETE', path: '/projects/p1/phases/p1_phase_2' },
  // Each lifecycle probe targets a phase for which the transition would be
  // legal, so a leak would show up as a 200 rather than hide behind a 409.
  { method: 'POST', path: '/projects/p1/phases/p1_phase_2/start' },
  {
    method: 'POST',
    path: '/projects/p1/phases/p1_phase_2/submit',
    body: { employeeId: 'rival_e1' },
  },
  { method: 'POST', path: '/projects/p1/phases/p1_phase_1/review', body: { approved: true } },
  { method: 'GET', path: '/projects/p1/phases/p1_phase_1/reports' },
  { method: 'GET', path: `/projects/p1/workers/e1/sequence?day=${DAY}` },
  {
    method: 'PUT',
    path: `/projects/p1/workers/e1/sequence?day=${DAY}`,
    body: { orderedPhaseIds: ['p1_phase_2'] },
  },
  { method: 'DELETE', path: `/projects/p1/workers/e1/sequence?day=${DAY}` },
  { method: 'GET', path: `/workers/e1/sequence?day=${DAY}` },
  { method: 'GET', path: '/media/:demoMediaId' },
  { method: 'GET', path: '/media/:demoMediaId/signed-url' },
  { method: 'GET', path: '/media/:demoMediaId/content' },
  { method: 'DELETE', path: '/media/:demoMediaId' },
  { method: 'POST', path: '/notifications/:demoNotificationId/read' },
  { method: 'POST', path: '/notifications/:demoNotificationId/unread' },
  // The rival's own project, with a demo id further down the path.
  { method: 'GET', path: '/projects/rival_p1/phases/p1_phase_1' },
  { method: 'PATCH', path: '/projects/rival_p1/phases/p1_phase_1', body: { name: 'Taken over' } },
  { method: 'POST', path: '/projects/rival_p1/phases/p1_phase_1/start' },
  { method: 'GET', path: `/projects/rival_p1/workers/e1/sequence?day=${DAY}` },
  {
    method: 'PUT',
    path: `/projects/rival_p1/workers/e1/sequence?day=${DAY}`,
    body: { orderedPhaseIds: [] },
  },
];

/**
 * Demo ids smuggled into the body of a write against the rival's own data.
 * These answer 400 (an unknown id is invalid input), exactly as for an id that
 * never existed -- the point is that the foreign id is never *accepted*.
 */
const RIVAL_FOREIGN_IDS_IN_BODY: Probe[] = [
  { method: 'POST', path: '/projects', body: { name: 'Planted', clientId: 'c1' } },
  { method: 'PATCH', path: '/projects/rival_p1', body: { clientId: 'c1' } },
  { method: 'PATCH', path: '/projects/rival_p1', body: { assignedEmployeeIds: ['e1'] } },
  {
    method: 'POST',
    path: '/projects/rival_p1/phases',
    body: { name: 'Planted', startDate: DAY, endDate: DAY, assignedEmployeeIds: ['e1'] },
  },
  {
    method: 'POST',
    path: '/projects/rival_p1/phases/:rivalPhaseId/submit',
    body: { employeeId: 'e1' },
  },
  {
    method: 'POST',
    path: '/projects/rival_p1/phases/reorder',
    body: { phaseIds: ['p1_phase_1'] },
  },
];

/** A rival *worker* session aimed at demo data. */
const RIVAL_WORKER_NOT_FOUND: Probe[] = [
  { method: 'GET', path: '/worker/projects/p1' },
  { method: 'POST', path: '/worker/arrivals', body: { projectId: 'p1' } },
  { method: 'GET', path: '/projects/p1/phases' },
  { method: 'GET', path: '/projects/p1/phases/p1_phase_1' },
  { method: 'POST', path: '/projects/p1/phases/p1_phase_2/start' },
  { method: 'POST', path: '/projects/p1/phases/p1_phase_2/submit', body: {} },
  { method: 'GET', path: `/projects/p1/workers/e1/sequence?day=${DAY}` },
  { method: 'GET', path: `/workers/e1/sequence?day=${DAY}` },
  { method: 'GET', path: '/media/:demoMediaId' },
  { method: 'GET', path: '/media/:demoMediaId/content' },
];

/** The same isolation, the other way round. */
const DEMO_FOREMAN_NOT_FOUND: Probe[] = [
  { method: 'GET', path: '/clients/rival_c1' },
  { method: 'GET', path: '/employees/rival_e1' },
  { method: 'POST', path: '/employees/rival_e1/login-ticket' },
  { method: 'GET', path: '/projects/rival_p1' },
  { method: 'GET', path: '/projects/rival_p1/phases' },
  { method: 'GET', path: '/projects/rival_p1/phases/:rivalPhaseId' },
  { method: 'GET', path: '/media/:rivalMediaId' },
  { method: 'POST', path: '/notifications/:rivalNotificationId/read' },
];

/**
 * By design these are refused with 403 CROSS_TENANT by `TenantGuard`, before
 * any handler runs: the request names the other company outright. That 403
 * reveals nothing a 404 would hide -- a company id is not a secret resource.
 */
const RIVAL_NAMES_DEMO_COMPANY: Probe[] = [
  { method: 'GET', path: `/clients?companyId=${DEMO_COMPANY_ID}` },
  { method: 'GET', path: `/projects?companyId=${DEMO_COMPANY_ID}` },
  {
    method: 'POST',
    path: '/clients',
    body: { companyId: DEMO_COMPANY_ID, name: 'Planted', type: 'company' },
  },
  { method: 'PATCH', path: '/company', body: { companyId: DEMO_COMPANY_ID, name: 'Taken over' } },
];

/**
 * Lists each foreman can read, and an id each one must find there -- the
 * positive control that keeps "no foreign ids" from passing on an empty list.
 */
const FOREMAN_LISTS: { path: string; demoSees: string; rivalSees: string }[] = [
  { path: '/clients?limit=200', demoSees: 'c1', rivalSees: 'rival_c1' },
  { path: '/employees?limit=200', demoSees: 'e1', rivalSees: 'rival_e1' },
  { path: '/projects?limit=200', demoSees: 'p1', rivalSees: 'rival_p1' },
  {
    path: '/notifications?limit=200',
    demoSees: ':demoNotificationId',
    rivalSees: ':rivalNotificationId',
  },
  { path: `/sequences?day=${DAY}`, demoSees: 'p1_phase_1', rivalSees: ':rivalPhaseId' },
  { path: '/telemetry/latest', demoSees: 'e1', rivalSees: 'rival_e1' },
  { path: '/telemetry/locations', demoSees: 'e1', rivalSees: 'rival_e1' },
  { path: '/arrivals', demoSees: ':demoArrivalId', rivalSees: ':rivalArrivalId' },
  { path: '/company', demoSees: DEMO_COMPANY_ID, rivalSees: OTHER_COMPANY_ID },
  { path: '/me/profile', demoSees: 'foreman_local', rivalSees: 'rival_foreman' },
  { path: '/auth/me', demoSees: 'foreman_local', rivalSees: 'rival_foreman' },
];

const WORKER_LISTS: { path: string; demoSees: string; rivalSees: string }[] = [
  { path: '/worker/projects?includeDone=true', demoSees: 'p1', rivalSees: 'rival_p1' },
  { path: '/worker/me', demoSees: 'e1', rivalSees: 'rival_e1' },
  { path: '/auth/me', demoSees: 'e1', rivalSees: 'rival_e1' },
];

/**
 * List filters naming a demo id. The rival gets an empty page, identical to
 * the one for an id that never existed, so the filter is no existence oracle.
 * The demo foreman's answer to the same filter is the control: non-empty.
 */
const FILTERS_NAMING_DEMO_IDS: { path: string; unknownPath: string }[] = [
  {
    path: '/telemetry/locations?employeeId=e1',
    unknownPath: '/telemetry/locations?employeeId=never-existed',
  },
  { path: '/arrivals?employeeId=e1', unknownPath: '/arrivals?employeeId=never-existed' },
  { path: '/arrivals?projectId=p1', unknownPath: '/arrivals?projectId=never-existed' },
  { path: '/projects?clientId=c1', unknownPath: '/projects?clientId=never-existed' },
  {
    path: '/projects?assignedEmployeeId=e1',
    unknownPath: '/projects?assignedEmployeeId=never-existed',
  },
];

const TENANT_MODELS = [...PrismaService.tenantScopedModels].sort();

describe('tenancy (e2e)', () => {
  let t: TestApp;
  let demo: ForemanSession;
  let rival: ForemanSession;
  let demoWorker: WorkerSession;
  let rivalWorker: WorkerSession;

  /** Ids created in `beforeAll`, substituted for `:name` in probe paths. */
  const ids: Record<string, string> = {};
  /** Every id owned by each tenant: seeded, plus whatever `beforeAll` creates. */
  const demoIds = new Set<string>(DEMO_SEED_IDS);
  const rivalIds = new Set<string>(RIVAL_SEED_IDS);

  let demoRowsBefore: Map<string, Row[]>;
  let demoCompanyBefore: unknown;

  beforeAll(async () => {
    t = await createTestApp();
    await resetDb(t.prisma);
    demo = await loginForeman(t, 'demo');
    rival = await loginForeman(t, 'rival');
    demoWorker = await workerSession(t, demo.accessToken, 'e1');
    rivalWorker = await workerSession(t, rival.accessToken, 'rival_e1');

    // The seed has no media, notifications, arrivals, location samples,
    // reports or manual sequences. Create one of each, in both tenants, through
    // the API -- so the probes target real rows and every list has something
    // in it on both sides.

    // --- demo ---------------------------------------------------------------
    remember('demo', 'demoMediaId', await uploadPng(demo.accessToken, 'demo.png'));

    const demoArrival = await t.http
      .post('/worker/arrivals')
      .set(bearer(demoWorker.accessToken))
      .send({ projectId: 'p1' })
      .expect(201);
    remember('demo', 'demoArrivalId', (demoArrival.body as { id: string }).id);

    await recordLocation(demoWorker.accessToken);

    // Moves p1_phase_1 to pendingReview, so a leaked review would succeed.
    const demoReport = await t.http
      .post('/worker/reports')
      .set(bearer(demoWorker.accessToken))
      .field('projectId', 'p1')
      .field('phaseId', 'p1_phase_1')
      .field('description', 'Demo report')
      .field('submittedAt', new Date().toISOString())
      .expect(201);
    remember('demo', 'demoReportId', (demoReport.body as { id: string }).id);

    // A manual order the rival's DELETE would wipe if it got through.
    await t.http
      .put(`/projects/p1/workers/e1/sequence?day=${DAY}`)
      .set(bearer(demo.accessToken))
      .send({ orderedPhaseIds: ['p1_phase_1'] })
      .expect(200);

    const demoNotifications = await notificationIds(demo.accessToken);
    for (const id of demoNotifications) demoIds.add(id);
    ids.demoNotificationId = demoNotifications[0] ?? '';

    // --- rival --------------------------------------------------------------
    await t.http
      .patch('/projects/rival_p1')
      .set(bearer(rival.accessToken))
      .send({ assignedEmployeeIds: ['rival_e1'] })
      .expect(200);

    const rivalPhase = await t.http
      .post('/projects/rival_p1/phases')
      .set(bearer(rival.accessToken))
      .send({
        name: 'Rival phase',
        startDate: DAY,
        endDate: DAY,
        assignedEmployeeIds: ['rival_e1'],
      })
      .expect(201);
    remember('rival', 'rivalPhaseId', (rivalPhase.body as { id: string }).id);

    // Byte-identical to the demo upload: de-duplication must stay per tenant.
    remember('rival', 'rivalMediaId', await uploadPng(rival.accessToken, 'rival.png'));

    const rivalArrival = await t.http
      .post('/worker/arrivals')
      .set(bearer(rivalWorker.accessToken))
      .send({ projectId: 'rival_p1' })
      .expect(201);
    remember('rival', 'rivalArrivalId', (rivalArrival.body as { id: string }).id);

    await recordLocation(rivalWorker.accessToken);

    const rivalNotifications = await notificationIds(rival.accessToken);
    for (const id of rivalNotifications) rivalIds.add(id);
    ids.rivalNotificationId = rivalNotifications[0] ?? '';

    expect(ids.demoNotificationId).not.toBe('');
    expect(ids.rivalNotificationId).not.toBe('');

    demoRowsBefore = await tenantRows(DEMO_COMPANY_ID);
    demoCompanyBefore = await t.prisma.company.findUnique({ where: { id: DEMO_COMPANY_ID } });
  });

  afterAll(async () => {
    await t.close();
  });

  function remember(owner: 'demo' | 'rival', name: string, id: string): void {
    ids[name] = id;
    (owner === 'demo' ? demoIds : rivalIds).add(id);
  }

  async function uploadPng(token: string, filename: string): Promise<string> {
    const res = await t.http
      .post('/media')
      .set(bearer(token))
      .attach('file', PNG, filename)
      .expect(201);
    return (res.body as { id: string }).id;
  }

  async function recordLocation(token: string): Promise<void> {
    await t.http
      .post('/worker/locations')
      .set(bearer(token))
      .send({
        samples: [{ latitude: 46.77, longitude: 23.62, capturedAt: new Date().toISOString() }],
      })
      .expect(200);
  }

  async function notificationIds(token: string): Promise<string[]> {
    const res = await t.http.get('/notifications?limit=200').set(bearer(token)).expect(200);
    return (res.body as { items: { id: string }[] }).items.map((item) => item.id);
  }

  function send(probe: Probe, token: string): Promise<Response> {
    const request = requestRoute(t, probe, fillPathParams(probe.path, ids)).set(bearer(token));
    return probe.body ? request.send(probe.body) : request;
  }

  async function tenantRows(companyId: string): Promise<Map<string, Row[]>> {
    const entries = await Promise.all(
      TENANT_MODELS.map(
        async (model) => [model, await rowsOf(t.prisma, model, companyId)] as const,
      ),
    );
    return new Map(entries);
  }

  describe('the rival foreman, on demo-company resources', () => {
    it.each(RIVAL_FOREMAN_NOT_FOUND.map((probe) => [label(probe), probe] as const))(
      '%s -> 404',
      async (_label, probe) => {
        const res = await send(probe, rival.accessToken);
        expect(outcome(res)).toEqual({ status: 404, code: 'NOT_FOUND' });
      },
    );

    it.each(RIVAL_FOREIGN_IDS_IN_BODY.map((probe) => [label(probe), probe] as const))(
      '%s naming a demo id in the body -> 400',
      async (_label, probe) => {
        const res = await send(probe, rival.accessToken);
        expect(outcome(res)).toEqual({ status: 400, code: 'VALIDATION_FAILED' });
      },
    );

    it('cannot attach a demo media id to its own work instructions', async () => {
      // The foreign key alone would accept it and leak the file into the
      // rival's phase; `MediaService.assertOwned` is what refuses it.
      const res = await t.http
        .post('/projects/rival_p1/phases')
        .set(bearer(rival.accessToken))
        .send({
          name: 'Planted',
          startDate: DAY,
          endDate: DAY,
          workInstructions: [{ text: 'Look', photoMediaIds: [ids.demoMediaId] }],
        });
      expect(outcome(res)).toEqual({ status: 400, code: 'VALIDATION_FAILED' });
      expect(errorOf(res).field).toBe('mediaIds');
    });

    it.each(RIVAL_NAMES_DEMO_COMPANY.map((probe) => [label(probe), probe] as const))(
      '%s naming the demo company -> 403 CROSS_TENANT',
      async (_label, probe) => {
        const res = await send(probe, rival.accessToken);
        expect(outcome(res)).toEqual({ status: 403, code: 'CROSS_TENANT' });
      },
    );

    it('uploading byte-identical media yields its own asset, not the demo one', async () => {
      expect(ids.rivalMediaId).not.toBe(ids.demoMediaId);
      const [demoAsset, rivalAsset] = await Promise.all([
        t.prisma.mediaAsset.findUnique({ where: { id: ids.demoMediaId } }),
        t.prisma.mediaAsset.findUnique({ where: { id: ids.rivalMediaId } }),
      ]);
      expect(demoAsset?.companyId).toBe(DEMO_COMPANY_ID);
      expect(rivalAsset?.companyId).toBe(OTHER_COMPANY_ID);
      expect(rivalAsset?.sha256).toBe(demoAsset?.sha256);
    });

    it('marking all read touches only its own notifications', async () => {
      await t.http.post('/notifications/read-all').set(bearer(rival.accessToken)).expect(200);
      const res = await t.http
        .get('/notifications/unread-count')
        .set(bearer(demo.accessToken))
        .expect(200);
      expect((res.body as { unreadCount: number }).unreadCount).toBeGreaterThan(0);
    });
  });

  describe('a rival worker, on demo-company resources', () => {
    it.each(RIVAL_WORKER_NOT_FOUND.map((probe) => [label(probe), probe] as const))(
      '%s -> 404',
      async (_label, probe) => {
        const res = await send(probe, rivalWorker.accessToken);
        expect(outcome(res)).toEqual({ status: 404, code: 'NOT_FOUND' });
      },
    );

    it('cannot file a report against a demo phase', async () => {
      const res = await t.http
        .post('/worker/reports')
        .set(bearer(rivalWorker.accessToken))
        .field('projectId', 'p1')
        .field('phaseId', 'p1_phase_2')
        .field('employeeId', 'e1')
        .field('description', 'Planted report')
        .field('submittedAt', new Date().toISOString());
      expect(outcome(res)).toEqual({ status: 404, code: 'NOT_FOUND' });
    });
  });

  describe('the demo foreman, on rival resources', () => {
    it.each(DEMO_FOREMAN_NOT_FOUND.map((probe) => [label(probe), probe] as const))(
      '%s -> 404',
      async (_label, probe) => {
        const res = await send(probe, demo.accessToken);
        expect(outcome(res)).toEqual({ status: 404, code: 'NOT_FOUND' });
      },
    );
  });

  describe('lists', () => {
    it.each(FOREMAN_LISTS)('GET $path shows the rival no demo ids', async (list) => {
      const res = await t.http.get(list.path).set(bearer(rival.accessToken)).expect(200);
      const seen = stringsIn(res.body);
      expect([...seen].filter((value) => demoIds.has(value))).toEqual([]);
      expect([...seen]).toContain(resolve(list.rivalSees));
    });

    it.each(FOREMAN_LISTS)('GET $path shows the demo foreman no rival ids', async (list) => {
      const res = await t.http.get(list.path).set(bearer(demo.accessToken)).expect(200);
      const seen = stringsIn(res.body);
      expect([...seen].filter(isRivalId)).toEqual([]);
      expect([...seen]).toContain(resolve(list.demoSees));
    });

    it.each(WORKER_LISTS)('GET $path shows a rival worker no demo ids', async (list) => {
      const res = await t.http.get(list.path).set(bearer(rivalWorker.accessToken)).expect(200);
      const seen = stringsIn(res.body);
      expect([...seen].filter((value) => demoIds.has(value))).toEqual([]);
      expect([...seen]).toContain(resolve(list.rivalSees));
    });

    it.each(WORKER_LISTS)('GET $path shows a demo worker no rival ids', async (list) => {
      const res = await t.http.get(list.path).set(bearer(demoWorker.accessToken)).expect(200);
      const seen = stringsIn(res.body);
      expect([...seen].filter(isRivalId)).toEqual([]);
      expect([...seen]).toContain(resolve(list.demoSees));
    });

    it.each(FILTERS_NAMING_DEMO_IDS)(
      'GET $path is empty for the rival, exactly as for an unknown id',
      async ({ path, unknownPath }) => {
        const [named, unknown, control] = await Promise.all([
          t.http.get(path).set(bearer(rival.accessToken)).expect(200),
          t.http.get(unknownPath).set(bearer(rival.accessToken)).expect(200),
          t.http.get(path).set(bearer(demo.accessToken)).expect(200),
        ]);
        expect(page(named).items).toEqual([]);
        expect(page(named)).toEqual(page(unknown));
        expect(page(control).items.length).toBeGreaterThan(0);
      },
    );

    function resolve(expected: string): string {
      return expected.startsWith(':') ? (ids[expected.slice(1)] ?? expected) : expected;
    }

    function isRivalId(value: string): boolean {
      return rivalIds.has(value) || value.startsWith('rival_');
    }
  });

  describe('coverage', () => {
    // Deliberate friction, as in the access matrix: a new route that takes an
    // id in its path fails here until a cross-tenant probe for it is added.
    it('every route with an id in its path is probed with a rival token', () => {
      const unprobed = declaredRoutes(AppModule)
        .filter((route) => !route.isPublic && route.path.includes(':'))
        .filter((route) => {
          const probes = route.roles.includes('foreman')
            ? RIVAL_FOREMAN_NOT_FOUND
            : RIVAL_WORKER_NOT_FOUND;
          return !probes.some((probe) => targets(probe, route));
        })
        .map((route) => route.label);
      expect(unprobed).toEqual([]);
    });

    const models = Prisma.dmmf.datamodel.models;
    const withCompanyId = models
      .filter((model) => model.fields.some((field) => field.name === 'companyId'))
      .map((model) => model.name)
      .sort();

    it('every model with a companyId is listed in PrismaService.tenantScopedModels, and vice versa', () => {
      expect(TENANT_MODELS).toEqual(withCompanyId);
    });

    it('companyId is required on every tenant-scoped model', () => {
      const optional = models
        .filter((model) =>
          model.fields.some((field) => field.name === 'companyId' && !field.isRequired),
        )
        .map((model) => model.name);
      expect(optional).toEqual([]);
    });
  });

  // Last: by now every rival write above has been attempted.
  describe('mutations do not cross', () => {
    it('the snapshot covers every kind of row the rival tried to reach', () => {
      // Guards the comparisons below against passing on two empty lists.
      const empty = [
        'Client',
        'Employee',
        'Project',
        'ProjectPhase',
        'PhaseSubmission',
        'DailySequenceOverride',
        'MediaAsset',
        'Notification',
        'WorkerArrival',
        'WorkerReport',
        'WorkerLocationSample',
        'WorkerLoginTicket',
      ].filter((model) => (demoRowsBefore.get(model) ?? []).length === 0);
      expect(empty).toEqual([]);
    });

    it.each(TENANT_MODELS)('every demo-company %s row is exactly as it was', async (model) => {
      expect(await rowsOf(t.prisma, model, DEMO_COMPANY_ID)).toEqual(demoRowsBefore.get(model));
    });

    it('the demo company record is exactly as it was', async () => {
      expect(await t.prisma.company.findUnique({ where: { id: DEMO_COMPANY_ID } })).toEqual(
        demoCompanyBefore,
      );
    });

    it.each(TENANT_MODELS)('no other-company %s row references a demo id', async (model) => {
      const rows = await rowsOf(t.prisma, model, OTHER_COMPANY_ID);
      expect([...stringsIn(rows)].filter((value) => demoIds.has(value))).toEqual([]);
    });
  });
});

type Row = Record<string, unknown>;

interface ErrorEnvelope {
  error?: { code?: string; field?: string };
}

function errorOf(res: Response): NonNullable<ErrorEnvelope['error']> {
  return (res.body as ErrorEnvelope).error ?? {};
}

/** Status plus `error.code`, so a failure shows both in one diff. */
function outcome(res: Response): { status: number; code: string | undefined } {
  return { status: res.status, code: errorOf(res).code };
}

/** The tenant-independent part of a list response (`from`/`to` are clock-derived). */
function page(res: Response): { items: unknown[]; page: unknown } {
  const body = res.body as { items: unknown[]; page: unknown };
  return { items: body.items, page: body.page };
}

/** True when `probe` is a request to `route`: same verb, path fits the template. */
function targets(probe: Probe, route: RouteInfo): boolean {
  if (probe.method !== route.method) return false;
  const pattern = route.path
    .split('/')
    .map((segment) =>
      segment.startsWith(':') ? '[^/]+' : segment.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'),
    )
    .join('/');
  return new RegExp(`^${pattern}$`).test(probe.path.split('?')[0] ?? '');
}

/** Every string in a JSON-ish value, keys included (`phaseNames` is keyed by phase id). */
function stringsIn(value: unknown, out = new Set<string>()): Set<string> {
  if (typeof value === 'string') {
    out.add(value);
  } else if (Array.isArray(value)) {
    for (const item of value) stringsIn(item, out);
  } else if (typeof value === 'object' && value !== null && !(value instanceof Date)) {
    for (const [key, item] of Object.entries(value)) {
      out.add(key);
      stringsIn(item, out);
    }
  }
  return out;
}

/** Every row of one tenant in one table, in a stable order. */
async function rowsOf(prisma: PrismaService, model: string, companyId: string): Promise<Row[]> {
  const delegates = prisma as unknown as Record<
    string,
    { findMany(args: { where: { companyId: string } }): Promise<Row[]> } | undefined
  >;
  const delegate = delegates[model.charAt(0).toLowerCase() + model.slice(1)];
  if (!delegate) throw new Error(`PrismaService has no delegate for model ${model}`);
  const rows = await delegate.findMany({ where: { companyId } });
  return rows.sort((a, b) => sortKey(a).localeCompare(sortKey(b)));
}

function sortKey(row: Row): string {
  return JSON.stringify(row, (_key, value: unknown) =>
    typeof value === 'bigint' ? value.toString() : value,
  );
}
