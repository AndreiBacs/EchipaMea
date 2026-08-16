import { ExecutionContext, createParamDecorator } from '@nestjs/common';
import { AppException } from '../errors/app-exception';
import type { ForemanPrincipal, Principal, WorkerPrincipal } from '../auth/principal';

interface RequestWithPrincipal {
  principal?: Principal;
}

/** The authenticated principal. Throws on a route that somehow has none. */
export const CurrentPrincipal = createParamDecorator(
  (_data: unknown, context: ExecutionContext): Principal => {
    const request = context.switchToHttp().getRequest<RequestWithPrincipal>();
    if (!request.principal) {
      throw AppException.unauthenticated('No authenticated principal on this request.');
    }
    return request.principal;
  },
);

/** Narrows to a foreman/admin principal; rejects a worker token. */
export const CurrentForeman = createParamDecorator(
  (_data: unknown, context: ExecutionContext): ForemanPrincipal => {
    const request = context.switchToHttp().getRequest<RequestWithPrincipal>();
    const principal = request.principal;
    if (!principal || principal.kind !== 'user') {
      throw AppException.forbidden('This operation requires a foreman account.');
    }
    return principal;
  },
);

/** Narrows to a worker principal; rejects a foreman token. */
export const CurrentWorker = createParamDecorator(
  (_data: unknown, context: ExecutionContext): WorkerPrincipal => {
    const request = context.switchToHttp().getRequest<RequestWithPrincipal>();
    const principal = request.principal;
    if (!principal || principal.kind !== 'employee') {
      throw AppException.forbidden('This operation requires a worker session.');
    }
    return principal;
  },
);
