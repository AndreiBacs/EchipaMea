import { CanActivate, ExecutionContext, Injectable } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import type { Request } from 'express';
import { AppConfig } from '../../common/config/configuration';
import { RequestContextService } from '../../common/context/request-context.service';
import {
  ALLOW_ANONYMOUS_WORKER_KEY,
  IS_PUBLIC_KEY,
} from '../../common/decorators/public.decorator';
import { AppException } from '../../common/errors/app-exception';
import type { Principal } from '../../common/auth/principal';
import { PrincipalResolverService } from '../principal-resolver.service';
import { TokenService } from '../token.service';

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
  constructor(
    private readonly reflector: Reflector,
    private readonly tokens: TokenService,
    private readonly principals: PrincipalResolverService,
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
        const principal = await this.principals.anonymous();
        this.attach(request, principal);
        return true;
      }
      throw AppException.unauthenticated('Missing bearer token.');
    }

    const claims = this.tokens.verifyAccessToken(token);
    const principal = await this.principals.fromClaims(claims);
    this.attach(request, principal);
    return true;
  }

  private attach(request: AuthenticatedRequest, principal: Principal): void {
    request.principal = principal;
    this.context.setPrincipal(principal);
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
