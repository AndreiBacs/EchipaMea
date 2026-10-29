import { Global, Module } from '@nestjs/common';
import { ClsModule } from 'nestjs-cls';
import type { Request, Response } from 'express';
import { ulid } from 'ulid';
import { RequestContextService } from './request-context.service';

/** Header clients and proxies may use to propagate an existing correlation id. */
export const TRACE_ID_HEADER = 'x-trace-id';

@Global()
@Module({
  imports: [
    ClsModule.forRoot({
      global: true,
      middleware: {
        mount: true,
        /**
         * The trace id is assigned in CLS's own `setup` hook rather than in a
         * separate middleware. Two reasons:
         *
         *  - `setup` runs *inside* the CLS context. A standalone middleware
         *    registered via `configure()` can run before ClsMiddleware, so its
         *    `cls.set()` lands nowhere and every request reports "no-trace".
         *  - Middleware runs before guards, so authentication and authorisation
         *    failures -- the errors most worth correlating -- still get an id.
         */
        setup: (cls, req: Request, res: Response) => {
          const traceId = normaliseInbound(req.headers[TRACE_ID_HEADER]) ?? ulid();
          cls.set('traceId', traceId);
          res.setHeader(TRACE_ID_HEADER, traceId);
        },
      },
    }),
  ],
  providers: [RequestContextService],
  exports: [RequestContextService],
})
export class RequestContextModule {}

/**
 * An inbound id is honoured so a mobile client or gateway can correlate its own
 * logs with ours, but it is length-capped and character-checked: an unchecked
 * value would let a caller inject newlines and forge log lines.
 */
function normaliseInbound(value: string | string[] | undefined): string | undefined {
  const raw = Array.isArray(value) ? value[0] : value;
  if (!raw) return undefined;
  const trimmed = raw.trim().slice(0, 64);
  return /^[\w.:-]+$/.test(trimmed) ? trimmed : undefined;
}
