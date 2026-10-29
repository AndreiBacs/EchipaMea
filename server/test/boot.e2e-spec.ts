import { createTestApp } from './support/app';
import { loginForeman } from './support/auth';

/**
 * What a fresh deployment does on its own: the Docker image only migrates and
 * starts, so with SEED_DEMO on, the app itself must leave a usable demo behind.
 */
describe('boot (e2e)', () => {
  it('seeds both demo tenants into an empty database when SEED_DEMO is on', async () => {
    const empty = await createTestApp();
    await empty.prisma.truncateAll();
    await empty.close();

    const t = await createTestApp({ SEED_DEMO: true });
    try {
      const companies = await t.prisma.company.findMany({ select: { id: true } });
      expect(companies.map((c) => c.id).sort()).toEqual(['demo-company', 'other-company']);

      const session = await loginForeman(t);
      expect(session.user.companyId).toBe('demo-company');

      await t.http.get('/health/ready').expect(200);
    } finally {
      await t.close();
    }
  });

  it('leaves the database alone when SEED_DEMO is off', async () => {
    const empty = await createTestApp();
    await empty.prisma.truncateAll();
    await empty.close();

    const t = await createTestApp();
    try {
      expect(await t.prisma.company.count()).toBe(0);
    } finally {
      await t.close();
    }
  });
});
