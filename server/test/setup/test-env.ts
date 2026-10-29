import * as fs from 'fs';
import * as os from 'os';
import * as path from 'path';

export const SERVER_ROOT = path.resolve(__dirname, '..', '..');

/**
 * Resolves the database the e2e suite is allowed to touch.
 *
 * Every suite starts with `truncateAll()`, so pointing this at the dev database
 * would wipe it. The name must end in `_test`; anything else is refused before
 * a single connection is opened.
 */
export function resolveTestDatabaseUrl(): string {
  loadDotEnvWithoutOverriding(path.join(SERVER_ROOT, '.env'));

  const url = process.env.TEST_DATABASE_URL;
  if (!url) {
    throw new Error(
      'TEST_DATABASE_URL is not set. Point it at a disposable Postgres database whose ' +
        'name ends in "_test" (see server/.env.example).',
    );
  }

  const database = new URL(url).pathname.replace(/^\//, '');
  if (!database.endsWith('_test')) {
    throw new Error(
      `Refusing to run e2e tests against "${database}": the database name must end in ` +
        '"_test", because every suite truncates every table.',
    );
  }
  return url;
}

/**
 * The environment every e2e app boots with. Real env vars set by CI still win
 * for anything not listed here; these are the values a test depends on.
 */
export function applyTestEnv(): void {
  const databaseUrl = resolveTestDatabaseUrl();
  Object.assign(process.env, {
    NODE_ENV: 'test',
    DATABASE_URL: databaseUrl,
    LOG_LEVEL: 'warn',
    CORS_ORIGINS: '*',
    JWT_ALG: 'HS256',
    JWT_SECRET: 'e2e-only-secret-0123456789abcdef0123456789abcdef',
    JWT_PRIVATE_KEY: '',
    JWT_PUBLIC_KEY: '',
    PHASE_TRANSITIONS_LENIENT: 'false',
    I_ACCEPT_INSECURE_TRANSITION: 'false',
    SEED_DEMO: 'false',
    RETENTION_JOBS_ENABLED: 'false',
    STORAGE_DRIVER: 'local',
    STORAGE_LOCAL_DIR: path.join(os.tmpdir(), `echipamea-e2e-${process.pid}`),
  });
}

/** Like `process.loadEnvFile`, but a variable already set in the shell wins. */
function loadDotEnvWithoutOverriding(file: string): void {
  if (!fs.existsSync(file)) return;
  const before = { ...process.env };
  process.loadEnvFile(file);
  for (const [key, value] of Object.entries(before)) {
    process.env[key] = value;
  }
}
