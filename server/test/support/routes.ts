import { RequestMethod, type INestApplication, type Type } from '@nestjs/common';
import { METHOD_METADATA, MODULE_METADATA, PATH_METADATA } from '@nestjs/common/constants';
import { DiscoveryService, MetadataScanner, Reflector } from '@nestjs/core';
import type { Test } from 'supertest';
import type { PrincipalRole } from '../../src/common/auth/principal';
import { IS_PUBLIC_KEY } from '../../src/common/decorators/public.decorator';
import { ROLES_KEY } from '../../src/common/decorators/roles.decorator';
import type { TestApp } from './app';

export type HttpMethod = 'GET' | 'POST' | 'PUT' | 'PATCH' | 'DELETE';

/**
 * What `RolesGuard` admits on a route that carries no `@Roles`. Mirrors the
 * private `DEFAULT_ROLES` in `src/auth/guards/roles.guard.ts`; the access matrix
 * proves the two agree, because every unannotated route is probed with a worker
 * token and must refuse it.
 */
export const DEFAULT_ROLES: readonly PrincipalRole[] = ['foreman', 'admin'];

export interface RouteInfo {
  method: HttpMethod;
  /** The path template as Nest mounts it, e.g. `/projects/:projectId`. */
  path: string;
  /** `GET /projects/:projectId` -- what a generated test is named after. */
  label: string;
  controller: string;
  handler: string;
  /** `@Public()` on the handler or its class, handler winning. */
  isPublic: boolean;
  /** The roles `RolesGuard` lets through: `@Roles(...)`, or the fail-closed default. */
  roles: readonly PrincipalRole[];
}

/** Keyed by the `RequestMethod` number Nest stores under `METHOD_METADATA`. */
const SUPPORTED_METHODS: Partial<Record<number, HttpMethod>> = {
  [RequestMethod.GET]: 'GET',
  [RequestMethod.POST]: 'POST',
  [RequestMethod.PUT]: 'PUT',
  [RequestMethod.PATCH]: 'PATCH',
  [RequestMethod.DELETE]: 'DELETE',
};

const reflector = new Reflector();
const scanner = new MetadataScanner();

/**
 * Every route the running app actually mounted, read through `DiscoveryService`.
 *
 * This is the source of truth. It needs a booted app, though, and Jest collects
 * tests synchronously before any `beforeAll` runs -- so generated tests are
 * built from `declaredRoutes` instead, and a suite asserts the two agree.
 */
export function discoverRoutes(app: INestApplication): RouteInfo[] {
  const controllers = app
    .get(DiscoveryService)
    .getControllers()
    .map((wrapper) => wrapper.metatype)
    .filter((metatype): metatype is Type<unknown> => typeof metatype === 'function');
  return sortRoutes(controllers.flatMap(routesOf));
}

/**
 * The same routes, found by walking `@Module({ imports, controllers })` from
 * `root` without booting anything. Async dynamic modules (a `Promise` in
 * `imports`) cannot be walked synchronously and are skipped; none of them
 * declares controllers, and the comparison with `discoverRoutes` would expose
 * one that did.
 */
export function declaredRoutes(root: Type<unknown>): RouteInfo[] {
  const seen = new Set<unknown>();
  const controllers = new Set<Type<unknown>>();

  const visit = (entry: unknown): void => {
    if (!entry || seen.has(entry)) return;
    seen.add(entry);

    if (typeof entry === 'function') {
      for (const controller of metadataArray(MODULE_METADATA.CONTROLLERS, entry)) {
        if (typeof controller === 'function') controllers.add(controller as Type<unknown>);
      }
      for (const imported of metadataArray(MODULE_METADATA.IMPORTS, entry)) visit(imported);
      return;
    }

    if (typeof entry === 'object') {
      const dynamic = entry as {
        module?: unknown;
        controllers?: unknown;
        imports?: unknown;
        forwardRef?: unknown;
      };
      if (typeof dynamic.forwardRef === 'function') {
        visit((dynamic.forwardRef as () => unknown)());
        return;
      }
      visit(dynamic.module);
      for (const controller of asArray(dynamic.controllers)) {
        if (typeof controller === 'function') controllers.add(controller as Type<unknown>);
      }
      for (const imported of asArray(dynamic.imports)) visit(imported);
    }
  };

  visit(root);
  return sortRoutes([...controllers].flatMap(routesOf));
}

/** Reads one controller's routes from the decorator metadata Nest itself uses. */
export function routesOf(controller: Type<unknown>): RouteInfo[] {
  const prefixes = pathsOf(Reflect.getMetadata(PATH_METADATA, controller));
  const prototype = controller.prototype as Record<string, unknown>;
  const routes: RouteInfo[] = [];

  for (const name of scanner.getAllMethodNames(prototype)) {
    const handler = prototype[name];
    if (typeof handler !== 'function') continue;

    const rawMethod: unknown = Reflect.getMetadata(METHOD_METADATA, handler);
    if (typeof rawMethod !== 'number') continue;
    const method = SUPPORTED_METHODS[rawMethod];
    if (!method) {
      // Fail loudly rather than silently leaving a route out of the matrix.
      throw new Error(
        `${controller.name}.${name} is mounted with ${RequestMethod[rawMethod]}, which ` +
          'test/support/routes.ts does not know how to probe. Teach it.',
      );
    }

    const targets = [handler, controller];
    const isPublic = reflector.getAllAndOverride<boolean | undefined>(IS_PUBLIC_KEY, targets);
    const roles = reflector.getAllAndOverride<PrincipalRole[] | undefined>(ROLES_KEY, targets);

    for (const prefix of prefixes) {
      for (const suffix of pathsOf(Reflect.getMetadata(PATH_METADATA, handler))) {
        const path = joinPath(prefix, suffix);
        routes.push({
          method,
          path,
          label: `${method} ${path}`,
          controller: controller.name,
          handler: name,
          isPublic: isPublic === true,
          roles: roles ?? DEFAULT_ROLES,
        });
      }
    }
  }

  return routes;
}

/**
 * Seeded ids for path parameters, so a probe names a row that exists. Guards
 * run before handlers, so for the auth checks the value only has to route.
 */
export const SEED_PATH_PARAMS: Readonly<Record<string, string>> = {
  projectId: 'p1',
  phaseId: 'p1_phase_1',
  clientId: 'c1',
  employeeId: 'e1',
  workerId: 'e1',
};

/** `/projects/:projectId` -> `/projects/p1`; unknown params get a placeholder. */
export function fillPathParams(
  path: string,
  params: Readonly<Record<string, string>> = SEED_PATH_PARAMS,
): string {
  return path.replace(/:(\w+)/g, (_match, name: string) => params[name] ?? `unknown-${name}`);
}

/** Starts a supertest request for `route`, with path params filled from the seed. */
export function requestRoute(
  t: TestApp,
  route: Pick<RouteInfo, 'method' | 'path'>,
  path: string = fillPathParams(route.path),
): Test {
  switch (route.method) {
    case 'GET':
      return t.http.get(path);
    case 'POST':
      return t.http.post(path);
    case 'PUT':
      return t.http.put(path);
    case 'PATCH':
      return t.http.patch(path);
    case 'DELETE':
      return t.http.delete(path);
  }
}

function metadataArray(key: string, target: object): unknown[] {
  return asArray(Reflect.getMetadata(key, target));
}

function asArray(value: unknown): unknown[] {
  return Array.isArray(value) ? (value as unknown[]) : [];
}

function pathsOf(raw: unknown): string[] {
  if (Array.isArray(raw)) return (raw as unknown[]).map((p) => String(p));
  if (typeof raw === 'string') return [raw];
  return ['/'];
}

function joinPath(...parts: string[]): string {
  const segments = parts.map((part) => part.replace(/^\/+|\/+$/g, '')).filter(Boolean);
  return `/${segments.join('/')}`;
}

function sortRoutes(routes: RouteInfo[]): RouteInfo[] {
  return routes.sort((a, b) => a.path.localeCompare(b.path) || a.method.localeCompare(b.method));
}
