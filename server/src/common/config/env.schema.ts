import { z } from 'zod';

/**
 * Every environment variable the server reads, validated once at boot.
 *
 * A bad config should fail loudly on startup rather than at the first request
 * that happens to touch it -- and the transition flags in particular must never
 * be left on by accident in production (see `.superRefine` at the bottom).
 */

const bool = (defaultValue: boolean) =>
  z
    .enum(['true', 'false', '1', '0', ''])
    .optional()
    .transform((v) => (v === undefined || v === '' ? defaultValue : v === 'true' || v === '1'));

const int = (defaultValue: number) =>
  z
    .string()
    .optional()
    .transform((v, ctx) => {
      if (v === undefined || v === '') return defaultValue;
      const parsed = Number(v);
      if (!Number.isFinite(parsed) || !Number.isInteger(parsed)) {
        ctx.addIssue({ code: z.ZodIssueCode.custom, message: `expected an integer, got "${v}"` });
        return z.NEVER;
      }
      return parsed;
    });

const optionalString = z
  .string()
  .optional()
  .transform((v) => (v === undefined || v.trim() === '' ? undefined : v.trim()));

export const envSchema = z
  .object({
    NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
    PORT: int(3000),
    CORS_ORIGINS: z.string().default('*'),
    LOG_LEVEL: z.enum(['fatal', 'error', 'warn', 'info', 'debug', 'trace']).default('info'),

    DATABASE_URL: z.string().min(1, 'DATABASE_URL is required'),

    // --- JWT ---------------------------------------------------------------
    JWT_ALG: z.enum(['RS256', 'HS256']).default('RS256'),
    JWT_SECRET: optionalString,
    JWT_PRIVATE_KEY: optionalString,
    JWT_PUBLIC_KEY: optionalString,
    JWT_ISSUER: z.string().default('echipamea-api'),
    JWT_AUDIENCE: z.string().default('echipamea-app'),
    JWT_FOREMAN_ACCESS_TTL: z.string().default('60m'),
    JWT_WORKER_ACCESS_TTL: z.string().default('12h'),
    REFRESH_FOREMAN_TTL_DAYS: int(30),
    REFRESH_WORKER_TTL_DAYS: int(7),

    // --- Worker QR login ---------------------------------------------------
    WORKER_LOGIN_TICKET_TTL_SECONDS: int(90),
    APP_WORKER_LOGIN_URL: optionalString,

    // --- Realtime ----------------------------------------------------------
    REALTIME_TICKET_TTL_SECONDS: int(60),
    REALTIME_HEARTBEAT_INTERVAL_MS: int(30_000),

    // --- Transition flags --------------------------------------------------
    // ALLOW_ANONYMOUS_WORKER_REPORTS, REALTIME_ALLOW_ANONYMOUS,
    // REALTIME_ACCESS_TOKEN_IN_QUERY and DEFAULT_COMPANY_ID used to live here.
    // They are gone rather than defaulted off: every principal now belongs to a
    // company because its token says so, and a flag that can reintroduce
    // identity-free traffic into a multi-tenant product is not worth keeping
    // around for convenience.
    I_ACCEPT_INSECURE_TRANSITION: bool(false),
    PHASE_TRANSITIONS_LENIENT: bool(false),

    // --- Test hooks --------------------------------------------------------
    // Routes under /__e2e that let the app's end-to-end suite force
    // situations it must survive, such as a dropped socket. Off unless the
    // runner script turns it on.
    E2E_TEST_HOOKS: bool(false),

    // --- Storage -----------------------------------------------------------
    STORAGE_DRIVER: z.enum(['local', 's3']).default('local'),
    STORAGE_LOCAL_DIR: z.string().default('./storage'),
    STORAGE_PUBLIC_BASE_URL: z.string().default('http://localhost:3000'),
    S3_ENDPOINT: optionalString,
    S3_REGION: z.string().default('us-east-1'),
    S3_BUCKET: optionalString,
    S3_ACCESS_KEY_ID: optionalString,
    S3_SECRET_ACCESS_KEY: optionalString,
    S3_FORCE_PATH_STYLE: bool(true),
    S3_SIGNED_URL_TTL_SECONDS: int(900),

    // --- Uploads -----------------------------------------------------------
    UPLOAD_MAX_FILE_BYTES: int(25 * 1024 * 1024),
    UPLOAD_MAX_FILES: int(20),

    LOCATION_SAMPLE_RETENTION_DAYS: int(90),
    // The nightly prune job. Leave on for a single instance; with several,
    // turn it off on all but one.
    RETENTION_JOBS_ENABLED: bool(true),

    // --- Seeding -----------------------------------------------------------
    SEED_DEMO: bool(false),
    SEED_FOREMAN_EMAIL: z.string().default('foreman@echipamea.local'),
    SEED_FOREMAN_PASSWORD: z.string().default('foreman123'),
  })
  .superRefine((env, ctx) => {
    if (env.JWT_ALG === 'HS256' && !env.JWT_SECRET) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['JWT_SECRET'],
        message: 'JWT_SECRET is required when JWT_ALG=HS256',
      });
    }
    if (env.JWT_ALG === 'RS256' && (!env.JWT_PRIVATE_KEY || !env.JWT_PUBLIC_KEY)) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['JWT_PRIVATE_KEY'],
        message: 'JWT_PRIVATE_KEY and JWT_PUBLIC_KEY are required when JWT_ALG=RS256',
      });
    }

    if (env.STORAGE_DRIVER === 's3') {
      for (const key of ['S3_BUCKET', 'S3_ACCESS_KEY_ID', 'S3_SECRET_ACCESS_KEY'] as const) {
        if (!env[key]) {
          ctx.addIssue({
            code: z.ZodIssueCode.custom,
            path: [key],
            message: `${key} is required when STORAGE_DRIVER=s3`,
          });
        }
      }
    }

    const insecureFlags = (['PHASE_TRANSITIONS_LENIENT', 'SEED_DEMO'] as const).filter(
      (flag) => env[flag],
    );

    if (
      env.NODE_ENV === 'production' &&
      insecureFlags.length > 0 &&
      !env.I_ACCEPT_INSECURE_TRANSITION
    ) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['I_ACCEPT_INSECURE_TRANSITION'],
        message:
          `Refusing to boot: ${insecureFlags.join(', ')} enabled with NODE_ENV=production. ` +
          'These exist only for the Flutter client migration window. Turn them off, or set ' +
          'I_ACCEPT_INSECURE_TRANSITION=true to acknowledge the risk deliberately.',
      });
    }
  });

export type Env = z.infer<typeof envSchema>;

export function validateEnv(raw: Record<string, unknown>): Env {
  const result = envSchema.safeParse(raw);
  if (!result.success) {
    const details = result.error.issues
      .map((issue) => `  - ${issue.path.join('.') || '(root)'}: ${issue.message}`)
      .join('\n');
    throw new Error(`Invalid environment configuration:\n${details}`);
  }
  return result.data;
}
