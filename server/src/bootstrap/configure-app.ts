import { VersioningType } from '@nestjs/common';
import type { NestExpressApplication } from '@nestjs/platform-express';
import helmet from 'helmet';
import { AppConfig } from '../common/config/configuration';
import { TypeFieldWsAdapter } from '../realtime/type-field-ws.adapter';

/**
 * Everything `main.ts` applies to the app before `listen`.
 *
 * Shared with the e2e harness so the app under test is the app that ships:
 * a test app without `TypeFieldWsAdapter` would fall back to socket.io and
 * every socket assertion would be testing the wrong transport.
 */
export function configureApp(app: NestExpressApplication, config: AppConfig): void {
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
}
