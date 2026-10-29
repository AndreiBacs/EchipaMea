import { CanActivate, ExecutionContext, Injectable } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import type { Request } from 'express';
import { RequestContextService } from '../../common/context/request-context.service';
import { IS_PUBLIC_KEY } from '../../common/decorators/public.decorator';
import { AppException } from '../../common/errors/app-exception';
import type { Principal } from '../../common/auth/principal';
import { PrincipalResolverService } from '../principal-resolver.service';
import { TokenService } from '../token.service';

interface AuthenticatedRequest extends Request {
  principal?: Principal;
}

/**
 * Global authentication, fail-closed.
 *
 * A route is authenticated unless it carries `@Public()`. There is no softening
 * and no anonymous fallback: every request either presents a bearer token that
 * names a company, or it is refused.
 */
@Injectable()
export class JwtAuthGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly tokens: TokenService,
    private readonly principals: PrincipalResolverService,
    private readonly context: RequestContextService,
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
    if (!token) throw AppException.unauthenticated('Missing bearer token.');

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
