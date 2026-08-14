import { CanActivate, ExecutionContext, Injectable, Logger } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import type { Request } from 'express';
import { AppConfig } from '../../common/config/configuration';
import { RequestContextService } from '../../common/context/request-context.service';
import {
  ALLOW_ANONYMOUS_WORKER_KEY,
  IS_PUBLIC_KEY,
} from '../../common/decorators/public.decorator';
import { AppException } from '../../common/errors/app-exception';
import { ErrorCode } from '../../common/errors/error-codes';
import { PrismaService } from '../../common/prisma/prisma.service';
import { newSessionId } from '../../common/util/ids';
import type { Principal } from '../../common/auth/principal';
import { TokenService } from '../token.service';
import { PrincipalCache } from './principal-cache';

interface AuthenticatedRequest extends Request {
  principal?: Principal;
}

/**
 * Global authentication.
 *
 * Fail-closed: a route is authenticated unless it carries `@Public()`. The one
 * softening is `@AllowAnonymousWorker()`, which -- only while the transition
 * flag is on -- lets the not-yet-rewired Flutter client upload reports without
 * a token, attributed to the default tenant.
 */
@Injectable()
export class JwtAuthGuard implements CanActivate {
  private readonly logger = new Logger(JwtAuthGuard.name);
  private readonly cache = new PrincipalCache();

  constructor(
    private readonly reflector: Reflector,
    private readonly tokens: TokenService,
    private readonly prisma: PrismaService,
    private readonly context: RequestContextService,
    private readonly config: AppConfig,
  ) {}

  async canActivate(executionContext: ExecutionContext): Promise<boolean> {
    if (executionContext.getType() !== 'http') return true;

    const isPublic = this.reflector.getAllAndOverride<boolean>(IS_PUBLIC_KEY, [
      executionContext.getHandler(),
      executionContext.getClass(),
    ]);
    if (isPublic) return true;

    const request = executionContext.switchToHttp().getRequest<AuthenticatedRequest>();
    const token = extractBearer(request);

    if (!token) {
      const allowsAnonymous = this.reflector.getAllAndOverride<boolean>(
        ALLOW_ANONYMOUS_WORKER_KEY,
        [executionContext.getHandler(), executionContext.getClass()],
      );
      if (allowsAnonymous && this.config.allowAnonymousWorkerReports) {
        const principal = await this.buildAnonymousPrincipal();
        this.attach(request, principal);
        return true;
      }
      throw AppException.unauthenticated('Missing bearer token.');
    }

    const claims = this.tokens.verifyAccessToken(token);
    const principal = await this.resolvePrincipal(claims);
    this.attach(request, principal);
    return true;
  }

  private attach(request: AuthenticatedRequest, principal: Principal): void {
    request.principal = principal;
    this.context.setPrincipal(principal);
  }

  /**
   * Re-checks that the token's subject still exists and is enabled.
   *
   * A JWT stays cryptographically valid until it expires, so a fired worker
   * would otherwise keep full access for up to 12 hours. Cached briefly to keep
   * this off the hot path.
   */
  private async resolvePrincipal(claims: {
    role: 'admin' | 'foreman' | 'worker';
    companyId: string;
    sub: string;
    sid: string;
    userId?: string;
    employeeId?: string;
    email?: string;
  }): Promise<Principal> {
    const cacheKey = `${claims.companyId}:${claims.sid}:${claims.sub}`;
    const cached = this.cache.get(cacheKey);
    if (cached) return cached;

    if (await this.tokens.isSessionRevoked(claims.companyId, claims.sid)) {
      throw AppException.unauthenticated('This session has been revoked.', ErrorCode.TOKEN_INVALID);
    }

    let principal: Principal;

    if (claims.role === 'worker') {
      const employeeId = claims.employeeId ?? claims.sub;
      const employee = await this.prisma.employee.findFirst({
        where: { id: employeeId, companyId: claims.companyId, deletedAt: null },
        select: { id: true, isActive: true },
      });
      if (!employee || !employee.isActive) {
        throw AppException.forbidden('This worker is no longer active.', ErrorCode.ACCOUNT_DISABLED);
      }
      principal = {
        kind: 'employee',
        role: 'worker',
        employeeId: employee.id,
        companyId: claims.companyId,
        sessionId: claims.sid,
      };
    } else {
      const userId = claims.userId ?? claims.sub;
      const user = await this.prisma.user.findFirst({
        where: { id: userId, companyId: claims.companyId, deletedAt: null },
        select: { id: true, email: true, role: true, isActive: true },
      });
      if (!user || !user.isActive) {
        throw AppException.forbidden('This account is disabled.', ErrorCode.ACCOUNT_DISABLED);
      }
      principal = {
        kind: 'user',
        role: user.role === 'admin' ? 'admin' : 'foreman',
        userId: user.id,
        companyId: claims.companyId,
        email: user.email,
        sessionId: claims.sid,
      };
    }

    this.cache.set(cacheKey, principal);
    return principal;
  }

  /**
   * Tenant for unauthenticated legacy traffic. Explicit config wins; otherwise
   * fall back to the only company that exists, which is the common case for a
   * seeded dev or single-customer deployment.
   */
  private async buildAnonymousPrincipal(): Promise<Principal> {
    const configured = this.config.defaultCompanyId;
    let companyId = configured;

    if (!companyId) {
      const companies = await this.prisma.company.findMany({ select: { id: true }, take: 2 });
      if (companies.length === 1 && companies[0]) {
        companyId = companies[0].id;
      } else {
        this.logger.error(
          `Anonymous request rejected: DEFAULT_COMPANY_ID is unset and ${companies.length} companies exist.`,
        );
        throw AppException.unauthenticated(
          'Anonymous access is not configured for a specific company.',
        );
      }
    }

    return {
      kind: 'anonymous',
      role: 'worker',
      companyId,
      sessionId: newSessionId(),
    };
  }
}

function extractBearer(request: Request): string | undefined {
  const header = request.headers.authorization;
  if (!header) return undefined;
  const [scheme, value] = header.split(' ');
  if (!scheme || !value) return undefined;
  if (scheme.toLowerCase() !== 'bearer') return undefined;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : undefined;
}
