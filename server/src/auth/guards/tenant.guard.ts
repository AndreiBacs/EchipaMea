import { CanActivate, ExecutionContext, Injectable, Logger } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import type { Request } from 'express';
import { IS_PUBLIC_KEY } from '../../common/decorators/public.decorator';
import { AppException } from '../../common/errors/app-exception';
import { ErrorCode } from '../../common/errors/error-codes';
import type { Principal } from '../../common/auth/principal';

/**
 * Belt-and-braces tenancy check.
 *
 * Services scope their own queries by `companyId`; this guard independently
 * asserts that (a) the principal has a tenant at all, and (b) no request tries
 * to name a *different* tenant in its body or query. Cross-tenant bugs are
 * invisible in single-tenant testing, so the redundancy is deliberate.
 */
@Injectable()
export class TenantGuard implements CanActivate {
  private readonly logger = new Logger(TenantGuard.name);

  constructor(private readonly reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    if (context.getType() !== 'http') return true;

    const isPublic = this.reflector.getAllAndOverride<boolean>(IS_PUBLIC_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);
    if (isPublic) return true;

    const request = context.switchToHttp().getRequest<Request & { principal?: Principal }>();
    const principal = request.principal;
    if (!principal) throw AppException.unauthenticated();

    if (!principal.companyId) {
      throw AppException.forbidden('This session has no company context.', ErrorCode.CROSS_TENANT);
    }

    for (const source of [request.body, request.query, request.params]) {
      const claimed = readCompanyId(source);
      if (claimed && claimed !== principal.companyId) {
        this.logger.warn(
          `Cross-tenant attempt: principal company ${principal.companyId} requested ${claimed}`,
        );
        throw AppException.forbidden(
          'Request references a different company.',
          ErrorCode.CROSS_TENANT,
        );
      }
    }

    return true;
  }
}

function readCompanyId(source: unknown): string | undefined {
  if (typeof source !== 'object' || source === null) return undefined;
  const value = (source as Record<string, unknown>).companyId;
  return typeof value === 'string' && value.length > 0 ? value : undefined;
}
