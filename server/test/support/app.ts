import type { AddressInfo } from 'net';
import { ConfigService } from '@nestjs/config';
import { DiscoveryModule } from '@nestjs/core';
import type { NestExpressApplication } from '@nestjs/platform-express';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { AppModule } from '../../src/app.module';
import { configureApp } from '../../src/bootstrap/configure-app';
import { AppConfig } from '../../src/common/config/configuration';
import type { Env } from '../../src/common/config/env.schema';
import { PrismaService } from '../../src/common/prisma/prisma.service';

export interface TestApp {
  app: NestExpressApplication;
  /** supertest bound to the listening server, e.g. `t.http.get('/clients')`. */
  http: ReturnType<typeof request>;
  baseUrl: string;
  /** `ws://127.0.0.1:<port>` -- append a `WS_PATHS` entry and `?ticket=`. */
  wsUrl: string;
  prisma: PrismaService;
  close(): Promise<void>;
}

/**
 * Boots the real AppModule on an ephemeral port, configured exactly as
 * `main.ts` does it.
 *
 * `overrides` takes *parsed* config values and applies to this app only.
 * `ConfigModule.forRoot()` validates the environment once, when AppModule is
 * first imported, so flipping `process.env` between apps in one file would do
 * nothing; overriding what `AppConfig` reads does.
 */
export async function createTestApp(overrides: Partial<Env> = {}): Promise<TestApp> {
  const builder = Test.createTestingModule({ imports: [AppModule, DiscoveryModule] });

  if (Object.keys(overrides).length > 0) {
    builder.overrideProvider(AppConfig).useFactory({
      factory: (config: ConfigService<Env, true>) =>
        new AppConfig(withOverrides(config, overrides)),
      inject: [ConfigService],
    });
  }

  const moduleRef = await builder.compile();
  const app = moduleRef.createNestApplication<NestExpressApplication>({
    logger: ['error', 'warn'],
  });
  configureApp(app, app.get(AppConfig));
  await app.listen(0, '127.0.0.1');

  const { port } = app.getHttpServer().address() as AddressInfo;
  const baseUrl = `http://127.0.0.1:${port}`;

  return {
    app,
    http: request(baseUrl),
    baseUrl,
    wsUrl: `ws://127.0.0.1:${port}`,
    prisma: app.get(PrismaService),
    close: () => app.close(),
  };
}

function withOverrides(
  config: ConfigService<Env, true>,
  overrides: Partial<Env>,
): ConfigService<Env, true> {
  return new Proxy(config, {
    get(target, property, receiver) {
      if (property !== 'get') return Reflect.get(target, property, receiver) as unknown;
      return (key: keyof Env, options?: unknown) =>
        key in overrides ? overrides[key] : target.get(key, options as { infer: true });
    },
  });
}
