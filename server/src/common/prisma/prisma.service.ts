import { Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';
import { AppConfig } from '../config/configuration';
import { TENANT_SCOPED_MODELS, assertTenantScoped } from './tenant-guard.extension';

@Injectable()
export class PrismaService extends PrismaClient implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(PrismaService.name);

  constructor(private readonly config: AppConfig) {
    super({
      log:
        config.nodeEnv === 'development'
          ? [{ emit: 'event', level: 'query' }, 'warn', 'error']
          : ['warn', 'error'],
    });
  }

  async onModuleInit(): Promise<void> {
    await this.$connect();
    this.logger.log('Database connected');
  }

  async onModuleDestroy(): Promise<void> {
    await this.$disconnect();
  }

  /**
   * Deletes every row, respecting FK order. Test-harness only.
   */
  async truncateAll(): Promise<void> {
    if (this.config.isProduction) {
      throw new Error('truncateAll() must never run against production.');
    }
    const tables = await this.$queryRaw<{ tablename: string }[]>`
      SELECT tablename FROM pg_tables
      WHERE schemaname = 'public' AND tablename <> '_prisma_migrations'
    `;
    if (tables.length === 0) return;
    const list = tables.map((t) => `"public"."${t.tablename}"`).join(', ');
    await this.$executeRawUnsafe(`TRUNCATE TABLE ${list} RESTART IDENTITY CASCADE;`);
  }

  /** Models carrying a `companyId`, exposed for the tenancy assertion tests. */
  static get tenantScopedModels(): ReadonlySet<string> {
    return TENANT_SCOPED_MODELS;
  }

  /** Re-exported so services can assert their own ad-hoc raw queries. */
  static assertTenantScoped = assertTenantScoped;
}
