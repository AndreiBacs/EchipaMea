import { CanActivate, ExecutionContext, Injectable } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import type { Request } from 'express';
import { IS_PUBLIC_KEY } from '../../common/decorators/public.decorator';
import { ROLES_KEY } from '../../common/decorators/roles.decorator';
import { AppException } from '../../common/errors/app-exception';
import type { Principal, PrincipalRole } from '../../common/auth/principal';

/**
 * Role authorisation, fail-closed.
 *
 * An unannotated route is foreman/admin only. That default matters: workers
 * outnumber foremen and a worker token reaching `/clients` or `/employees`
 * would expose the whole company roster. Worker routes opt in with
 * `@Roles('worker')`.
 */
@Injectable()
export class RolesGuard implements CanActivate {
  private static readonly DEFAULT_ROLES: PrincipalRole[] = ['foreman', 'admin'];

  constructor(private readonly reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    if (context.getType() !== 'http') return true;

    const isPublic = this.reflector.getAllAndOverride<boolean>(IS_PUBLIC_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);
    if (isPublic) return true;

    const required =
      this.reflector.getAllAndOverride<PrincipalRole[]>(ROLES_KEY, [
        context.getHandler(),
        context.getClass(),
      ]) ?? RolesGuard.DEFAULT_ROLES;

    const request = context.switchToHttp().getRequest<Request & { principal?: Principal }>();
    const principal = request.principal;

    if (!principal) throw AppException.unauthenticated();

    if (!required.includes(principal.role)) {
      throw AppException.forbidden(
        `This operation requires one of: ${required.join(', ')}.`,
      );
    }

    return true;
  }
}
