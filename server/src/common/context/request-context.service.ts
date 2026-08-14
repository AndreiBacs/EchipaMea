import { Injectable } from '@nestjs/common';
import { ClsService, type ClsStore } from 'nestjs-cls';
import type { Principal } from '../auth/principal';

export interface RequestContextStore extends ClsStore {
  traceId: string;
  principal?: Principal;
}

/**
 * Per-request ambient state (trace id, authenticated principal).
 *
 * The principal lives here rather than only on the request object so that
 * non-HTTP call sites -- the Prisma tenancy extension, WebSocket handlers,
 * background helpers -- can read it without threading it through every call.
 */
@Injectable()
export class RequestContextService {
  constructor(private readonly cls: ClsService<RequestContextStore>) {}

  get traceId(): string {
    return this.cls.get('traceId') ?? 'no-trace';
  }

  setTraceId(traceId: string): void {
    this.cls.set('traceId', traceId);
  }

  /** The authenticated principal, or undefined on public/anonymous routes. */
  get principal(): Principal | undefined {
    return this.cls.get('principal');
  }

  setPrincipal(principal: Principal | undefined): void {
    this.cls.set('principal', principal);
  }

  /** The tenant of the current request, or undefined when unauthenticated. */
  get companyId(): string | undefined {
    return this.principal?.companyId;
  }

  /** True when there is an active CLS context to read from. */
  get isActive(): boolean {
    return this.cls.isActive();
  }
}
