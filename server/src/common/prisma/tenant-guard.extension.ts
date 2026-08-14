/**
 * Defence in depth against the classic multi-tenant bug: a query that forgets
 * to scope by `companyId` and quietly returns another contractor's data.
 *
 * Services are still expected to scope explicitly -- this is a backstop, not a
 * substitute. It is an *assertion* rather than an auto-injector on purpose:
 * silently rewriting a developer's `where` clause hides mistakes and fights
 * Prisma's generated types, whereas failing loudly surfaces them in tests.
 *
 * The real gate is `test/tenancy.e2e-spec.ts`, which probes every endpoint with
 * a second seeded tenant.
 */

/** Prisma models that carry a `companyId` column. */
export const TENANT_SCOPED_MODELS: ReadonlySet<string> = new Set([
  'User',
  'RefreshToken',
  'WorkerLoginTicket',
  'RealtimeTicket',
  'Client',
  'Employee',
  'Project',
  'ProjectAssignment',
  'ProjectPhase',
  'PhaseAssignment',
  'PhaseWorkInstruction',
  'PhaseSubmission',
  'PhaseReview',
  'DailySequenceOverride',
  'MediaAsset',
  'WorkInstructionMedia',
  'WorkerReportMedia',
  'WorkerReport',
  'WorkerArrival',
  'Notification',
  'WorkerLocationSample',
]);

/**
 * Lookups that legitimately have no tenant in hand, because the tenant is what
 * they are resolving: you cannot scope a login by company before you know which
 * company the credential belongs to.
 */
export const TENANT_BOOTSTRAP_LOOKUPS: ReadonlySet<string> = new Set([
  'User.email',
  'RefreshToken.tokenHash',
  'WorkerLoginTicket.ticketHash',
  'RealtimeTicket.ticketHash',
  'MediaAsset.storageKey',
  'WorkerReport.idempotencyKey',
]);

type UnknownRecord = Record<string, unknown>;

function isRecord(value: unknown): value is UnknownRecord {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

/**
 * True when `where` constrains the query to a single tenant, whether directly
 * (`companyId`), via a compound unique (`id_companyId`), or through a nested
 * relation filter that itself carries a companyId.
 */
export function hasTenantScope(where: unknown, depth = 0): boolean {
  if (!isRecord(where) || depth > 4) return false;

  if (where.companyId !== undefined) return true;

  for (const key of Object.keys(where)) {
    if (key.endsWith('_companyId') || key.startsWith('companyId_')) return true;
  }

  // AND / OR / NOT and nested relation filters.
  for (const [key, value] of Object.entries(where)) {
    if (Array.isArray(value)) {
      // OR is only scoped if *every* branch is scoped.
      if (key === 'OR') {
        if (value.length > 0 && value.every((branch) => hasTenantScope(branch, depth + 1))) {
          return true;
        }
        continue;
      }
      if (value.some((branch) => hasTenantScope(branch, depth + 1))) return true;
      continue;
    }
    if (isRecord(value) && hasTenantScope(value, depth + 1)) return true;
  }

  return false;
}

/** True when the `where` targets one of the bootstrap lookups above. */
export function isBootstrapLookup(model: string, where: unknown): boolean {
  if (!isRecord(where)) return false;
  return Object.keys(where).some((key) => TENANT_BOOTSTRAP_LOOKUPS.has(`${model}.${key}`));
}

export interface TenantAssertionInput {
  model: string;
  operation: string;
  where?: unknown;
  data?: unknown;
}

/**
 * Returns a human-readable reason when the query is not tenant-scoped, or
 * undefined when it is fine.
 */
export function assertTenantScoped(input: TenantAssertionInput): string | undefined {
  const { model, operation, where, data } = input;
  if (!TENANT_SCOPED_MODELS.has(model)) return undefined;

  if (CREATE_OPERATIONS.has(operation)) {
    const rows = Array.isArray(data) ? data : [data];
    const missing = rows.some((row) => !isRecord(row) || row.companyId === undefined);
    // A nested create inherits companyId from its parent write, so only
    // top-level creates are checked.
    return missing ? `${model}.${operation} is missing companyId in data` : undefined;
  }

  if (!SCOPED_OPERATIONS.has(operation)) return undefined;
  if (isBootstrapLookup(model, where)) return undefined;
  if (hasTenantScope(where)) return undefined;

  return `${model}.${operation} is missing a companyId constraint in where`;
}

const CREATE_OPERATIONS = new Set(['create', 'createMany', 'createManyAndReturn']);

const SCOPED_OPERATIONS = new Set([
  'findFirst',
  'findFirstOrThrow',
  'findMany',
  'findUnique',
  'findUniqueOrThrow',
  'update',
  'updateMany',
  'delete',
  'deleteMany',
  'upsert',
  'count',
  'aggregate',
  'groupBy',
]);
