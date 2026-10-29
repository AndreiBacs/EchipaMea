import { seedDemo } from '../../src/common/prisma/demo-seed';
import type { PrismaService } from '../../src/common/prisma/prisma.service';

/**
 * Empties every table and re-seeds both tenants.
 *
 * The seed upserts with `update: {}`, so on its own it would leave behind
 * whatever the previous suite changed; truncating first is what makes each
 * suite start from the same rows.
 */
export async function resetDb(prisma: PrismaService): Promise<void> {
  await prisma.truncateAll();
  await seedDemo(prisma);
}
