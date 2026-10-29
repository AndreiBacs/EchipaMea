/**
 * CLI entry for the demo seed (`npm run seed`, and `prisma migrate reset`).
 *
 * The data itself lives in `src/common/prisma/demo-seed.ts` so the app (via
 * `SEED_DEMO`) and the e2e harness seed exactly the same rows.
 */
import { PrismaClient } from '@prisma/client';
import {
  DEMO_COMPANY_ID,
  OTHER_COMPANY_ID,
  RIVAL_FOREMAN_EMAIL,
  defaultSeedCredentials,
  seedDemo,
} from '../src/common/prisma/demo-seed';

const prisma = new PrismaClient();

async function main(): Promise<void> {
  const credentials = defaultSeedCredentials();
  await seedDemo(prisma, credentials);

  console.log('Seed complete.');
  console.log(`  Demo tenant:  ${DEMO_COMPANY_ID}`);
  console.log(`  Foreman:      ${credentials.foremanEmail} / ${credentials.foremanPassword}`);
  console.log(`  Other tenant: ${OTHER_COMPANY_ID} (${RIVAL_FOREMAN_EMAIL})`);
}

main()
  .then(async () => {
    await prisma.$disconnect();
  })
  .catch(async (error: unknown) => {
    console.error(error);
    await prisma.$disconnect();
    process.exit(1);
  });
