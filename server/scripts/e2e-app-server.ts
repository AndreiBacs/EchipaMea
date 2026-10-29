/**
 * Serves the API for the Flutter app's end-to-end suite (`integration_test/`
 * at the repo root): `npm run e2e:app-server`, then run the suite against it.
 *
 * It uses the e2e test database (TEST_DATABASE_URL, whose name must end in
 * `_test`): migrates it, empties it and seeds both demo tenants, so every run
 * starts from the same rows. It then listens with the `/__e2e` hooks on and
 * a 15-second foreman access token, so the suite also proves that expired
 * tokens refresh. Stop it with Ctrl+C.
 *
 * E2E_APP_PORT (default 3100) and E2E_FOREMAN_ACCESS_TTL override the port and
 * token lifetime.
 */
import 'reflect-metadata';
import { execSync } from 'child_process';
import { writeFileSync } from 'fs';
import { NestFactory } from '@nestjs/core';
import type { NestExpressApplication } from '@nestjs/platform-express';
import { applyTestEnv, SERVER_ROOT } from '../test/setup/test-env';

async function main(): Promise<void> {
  applyTestEnv();
  const port = process.env.E2E_APP_PORT ?? '3100';
  Object.assign(process.env, {
    PORT: port,
    E2E_TEST_HOOKS: 'true',
    JWT_FOREMAN_ACCESS_TTL: process.env.E2E_FOREMAN_ACCESS_TTL ?? '15s',
  });

  execSync('npx prisma migrate deploy', { cwd: SERVER_ROOT, env: process.env, stdio: 'inherit' });

  // Imported only now: the config module reads the environment on import.
  const { AppModule } = await import('../src/app.module');
  const { configureApp } = await import('../src/bootstrap/configure-app');
  const { AppConfig } = await import('../src/common/config/configuration');
  const { PrismaService } = await import('../src/common/prisma/prisma.service');
  const { seedDemo } = await import('../src/common/prisma/demo-seed');

  const app = await NestFactory.create<NestExpressApplication>(AppModule, {
    logger: ['error', 'warn'],
  });
  configureApp(app, app.get(AppConfig));

  const prisma = app.get(PrismaService);
  await prisma.truncateAll();
  await seedDemo(prisma);

  await app.listen(Number(port), '127.0.0.1');
  // Lets scripts/e2e_app.sh stop this process: on Windows, killing the shell
  // job that started it does not reach node.
  if (process.env.E2E_APP_PIDFILE) {
    writeFileSync(process.env.E2E_APP_PIDFILE, String(process.pid));
  }
  // The runner script waits for this line.
  console.log(`e2e app server ready on http://127.0.0.1:${port}`);
}

main().catch((error: unknown) => {
  console.error(error);
  process.exit(1);
});
