import 'reflect-metadata';
import { Logger, VersioningType } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import type { NestExpressApplication } from '@nestjs/platform-express';
import helmet from 'helmet';
import { AppModule } from './app.module';
import { AppConfig } from './common/config/configuration';
import { PrismaService } from './common/prisma/prisma.service';
import { TypeFieldWsAdapter } from './realtime/type-field-ws.adapter';

async function bootstrap(): Promise<void> {
  const app = await NestFactory.create<NestExpressApplication>(AppModule, {
    bufferLogs: true,
  });

  const config = app.get(AppConfig);
  const logger = new Logger('Bootstrap');

  // Routes are mounted at the root on purpose: the Flutter client resolves
  // `AUTH_API_BASE_URL + /foreman/login` and holds full URLs for the report
  // upload and both sockets. A global prefix would force all of those to change
  // at once. Versioning happens via the OpenAPI `info.version`.
  app.setGlobalPrefix('');
  app.enableVersioning({ type: VersioningType.URI, defaultVersion: undefined });

  // Must be installed before `listen`. Nest's default gateway transport is
  // socket.io, which the Flutter client -- a raw RFC-6455 socket sending flat
  // `{"type": ...}` frames -- cannot talk to at all.
  app.useWebSocketAdapter(new TypeFieldWsAdapter(app));

  app.use(
    helmet({
      // The API serves JSON and media bytes, never HTML, so CSP would only
      // interfere with the signed-URL redirects.
      contentSecurityPolicy: false,
      crossOriginResourcePolicy: { policy: 'cross-origin' },
    }),
  );

  app.enableCors({
    origin: config.corsOrigins,
    credentials: true,
    exposedHeaders: ['x-trace-id', 'content-range', 'accept-ranges'],
  });

  app.set('trust proxy', 1);
  app.enableShutdownHooks();

  await app.listen(config.port, '0.0.0.0');
  logger.log(`EchipaMea API listening on port ${config.port} (${config.nodeEnv})`);
  logger.log(`Storage driver: ${config.storageDriver}`);

  if (config.allowAnonymousWorkerReports || config.realtimeAllowAnonymous) {
    logger.warn(
      'Anonymous transition flags are ON. These exist only for the Flutter client ' +
        'migration window -- turn them off once the app sends bearer tokens.',
    );

    // Without a tenant to attribute it to, anonymous access fail-closes at the
    // first request. That looks like the flags simply not working, so say it at
    // boot rather than leaving it to be discovered one 401 at a time.
    if (!config.defaultCompanyId) {
      const companies = await app.get(PrismaService).company.count();
      if (companies !== 1) {
        logger.warn(
          `DEFAULT_COMPANY_ID is unset and ${companies} companies exist, so anonymous ` +
            'requests will be rejected. Set it to the tenant the un-rewired app belongs to.',
        );
      }
    }
  }
}

void bootstrap();
