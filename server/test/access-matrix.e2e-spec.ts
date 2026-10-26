import type { Response } from 'supertest';
import { AppModule } from '../src/app.module';
import { createTestApp, type TestApp } from './support/app';
import {
  bearer,
  loginForeman,
  workerSession,
  type ForemanSession,
  type WorkerSession,
} from './support/auth';
import { resetDb } from './support/db';
import { declaredRoutes, discoverRoutes, requestRoute } from './support/routes';

/**
 * Authentication and role coverage for every HTTP route, generated from the
 * controllers rather than listed by hand -- a route added tomorrow is probed
 * tomorrow, with no edit to this file.
 *
 * Jest builds its test list before `beforeAll` can boot an app, so the tables
 * below come from walking the module graph (`declaredRoutes`). The first test
 * then checks that walk against what the running app actually mounted
 * (`DiscoveryService`), so a controller registered some other way cannot slip
 * past the matrix unnoticed.
 *
 * Every probe here is refused by a guard before it reaches a handler, so none
 * of them changes any data and their order does not matter. The exceptions are
 * the public routes, which get an empty body and stop at validation, and the
 * allowed-role checks, which only issue GETs.
 */

const ROUTES = declaredRoutes(AppModule);
const PROTECTED = ROUTES.filter((route) => !route.isPublic);
const NOT_FOR_WORKERS = PROTECTED.filter((route) => !route.roles.includes('worker'));
const NOT_FOR_FOREMEN = PROTECTED.filter((route) => !route.roles.includes('foreman'));
const GETS_FOR_WORKERS = PROTECTED.filter(
  (route) => route.method === 'GET' && route.roles.includes('worker'),
);
const GETS_FOR_FOREMEN = PROTECTED.filter(
  (route) => route.method === 'GET' && route.roles.includes('foreman'),
);

/**
 * The complete list of routes that answer without a token, and how each one
 * answers. Deliberate friction: adding `@Public()` anywhere fails this suite
 * until the route is added here, which is the moment to ask whether it should
 * be public at all.
 */
const PUBLIC_ROUTES: Record<string, { status: number; code?: string }> = {
  'GET /health/live': { status: 200 },
  'GET /health/ready': { status: 200 },
  'POST /auth/refresh': { status: 400, code: 'VALIDATION_FAILED' },
  'POST /foreman/login': { status: 400, code: 'VALIDATION_FAILED' },
  'POST /worker/login-tickets/redeem': { status: 400, code: 'VALIDATION_FAILED' },
};

describe('access matrix (e2e)', () => {
  let t: TestApp;
  let foreman: ForemanSession;
  let worker: WorkerSession;

  beforeAll(async () => {
    t = await createTestApp();
    await resetDb(t.prisma);
    foreman = await loginForeman(t);
    worker = await workerSession(t, foreman.accessToken, 'e1');
  });

  afterAll(async () => {
    await t.close();
  });

  describe('route discovery', () => {
    it('the generated tables cover exactly the routes the running app mounted', () => {
      const mounted = discoverRoutes(t.app).map((route) => route.label);
      expect(ROUTES.map((route) => route.label)).toEqual(mounted);
    });

    it('finds a plausible number of routes, each mounted once', () => {
      // A sudden drop means the walk broke, not that the API shrank.
      expect(ROUTES.length).toBeGreaterThanOrEqual(60);
      const labels = ROUTES.map((route) => route.label);
      expect(new Set(labels).size).toBe(labels.length);
    });

    it('exposes exactly the expected public routes', () => {
      const publicLabels = ROUTES.filter((route) => route.isPublic).map((route) => route.label);
      expect(publicLabels.sort()).toEqual(Object.keys(PUBLIC_ROUTES).sort());
    });

    it('has worker-only routes to probe with a foreman token', () => {
      // Guards the `it.each` below against silently becoming empty.
      expect(NOT_FOR_FOREMEN.map((route) => route.label)).toEqual(
        expect.arrayContaining(['GET /worker/me', 'GET /worker/projects']),
      );
    });
  });

  describe('public routes', () => {
    it.each(Object.entries(PUBLIC_ROUTES))(
      '%s answers without a token',
      async (label, expected) => {
        const route = ROUTES.find((candidate) => candidate.label === label);
        if (!route) throw new Error(`${label} is not mounted`);
        // An empty body: the auth POSTs must stop at validation (400), never
        // at authentication (401).
        const res = await requestRoute(t, route);
        expect(outcome(res)).toEqual({ status: expected.status, code: expected.code });
      },
    );
  });

  describe('without a token', () => {
    it.each(PROTECTED)('$label -> 401 UNAUTHENTICATED', async (route) => {
      const res = await requestRoute(t, route);
      expect(outcome(res)).toEqual({ status: 401, code: 'UNAUTHENTICATED' });
    });
  });

  describe('with a garbage bearer token', () => {
    it.each(PROTECTED)('$label -> 401 TOKEN_INVALID', async (route) => {
      const res = await requestRoute(t, route).set(bearer('not-a-real-token'));
      expect(outcome(res)).toEqual({ status: 401, code: 'TOKEN_INVALID' });
    });
  });

  // RolesGuard is fail-closed: a route without `@Roles` is foreman/admin only,
  // so this table includes every unannotated route.
  describe('with a worker token on a route workers may not use', () => {
    it.each(NOT_FOR_WORKERS)('$label -> 403 FORBIDDEN', async (route) => {
      const res = await requestRoute(t, route).set(bearer(worker.accessToken));
      expect(outcome(res)).toEqual({ status: 403, code: 'FORBIDDEN' });
    });
  });

  describe('with a foreman token on a worker-only route', () => {
    it.each(NOT_FOR_FOREMEN)('$label -> 403 FORBIDDEN', async (route) => {
      const res = await requestRoute(t, route).set(bearer(foreman.accessToken));
      expect(outcome(res)).toEqual({ status: 403, code: 'FORBIDDEN' });
    });
  });

  // The controls: without them, a broken token or an over-eager guard would
  // make every refusal above pass for the wrong reason. GETs only, so nothing
  // is mutated; a 400 (missing `?day=`) or 404 (placeholder id) still proves
  // the guards let the request through.
  describe('allowed roles get past the guards', () => {
    it.each(GETS_FOR_WORKERS)('$label lets a worker token through', async (route) => {
      const res = await requestRoute(t, route).set(bearer(worker.accessToken));
      expect([401, 403]).not.toContain(res.status);
    });

    it.each(GETS_FOR_FOREMEN)('$label lets a foreman token through', async (route) => {
      const res = await requestRoute(t, route).set(bearer(foreman.accessToken));
      expect([401, 403]).not.toContain(res.status);
    });
  });
});

interface ErrorEnvelope {
  error?: { code?: string };
}

/** Status plus `error.code`, so a failure shows both in one diff. */
function outcome(res: Response): { status: number; code: string | undefined } {
  return { status: res.status, code: (res.body as ErrorEnvelope).error?.code };
}
