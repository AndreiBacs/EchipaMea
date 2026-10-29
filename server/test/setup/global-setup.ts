import { execSync } from 'child_process';
import { SERVER_ROOT, resolveTestDatabaseUrl } from './test-env';

/** Brings the test database up to the latest migration once per run. */
export default function globalSetup(): void {
  const databaseUrl = resolveTestDatabaseUrl();
  execSync('npx prisma migrate deploy', {
    cwd: SERVER_ROOT,
    env: { ...process.env, DATABASE_URL: databaseUrl },
    stdio: 'pipe',
  });
}
