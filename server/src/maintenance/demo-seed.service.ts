import { Injectable, Logger, OnApplicationBootstrap } from '@nestjs/common';
import { AppConfig } from '../common/config/configuration';
import { seedDemo } from '../common/prisma/demo-seed';
import { PrismaService } from '../common/prisma/prisma.service';

/**
 * Honours `SEED_DEMO`: inserts the demo and rival tenants at boot, so
 * `docker compose up` gives a usable API without a separate seed step (the
 * runtime image has no ts-node to run `prisma/seed.ts` with).
 *
 * The seed is idempotent upserts, so this is safe on every restart. The
 * production guard in env.schema.ts refuses `SEED_DEMO` with
 * `NODE_ENV=production` unless the risk is acknowledged explicitly.
 */
@Injectable()
export class DemoSeedService implements OnApplicationBootstrap {
  private readonly logger = new Logger(DemoSeedService.name);

  constructor(
    private readonly config: AppConfig,
    private readonly prisma: PrismaService,
  ) {}

  async onApplicationBootstrap(): Promise<void> {
    if (!this.config.seedDemo) return;
    await seedDemo(this.prisma, {
      foremanEmail: this.config.seedForemanEmail,
      foremanPassword: this.config.seedForemanPassword,
    });
    this.logger.warn(
      `SEED_DEMO is on: demo tenants seeded (foreman ${this.config.seedForemanEmail}).`,
    );
  }
}
