/**
 * Who is making the current request.
 *
 * Every principal belongs to exactly one company. There is no unauthenticated
 * principal: a caller either proves who it is and which tenant it belongs to, or
 * it is refused. An earlier revision carried an `AnonymousPrincipal` attributed
 * to a configured default company, to keep the un-rewired Flutter client working
 * during the migration -- it is gone, along with the flags that enabled it,
 * because "traffic with no identity, filed under whichever tenant the config
 * names" is not something a multi-tenant product should be able to express.
 *
 * The app has two principal kinds with separate id spaces, so `sub` alone is
 * ambiguous -- `userId` and `employeeId` are always set explicitly instead.
 */
export type PrincipalRole = 'admin' | 'foreman' | 'worker';

export interface ForemanPrincipal {
  kind: 'user';
  role: 'admin' | 'foreman';
  userId: string;
  employeeId?: undefined;
  companyId: string;
  email: string;
  /** Session/rotation family id, used to revoke a whole login. */
  sessionId: string;
}

export interface WorkerPrincipal {
  kind: 'employee';
  role: 'worker';
  userId?: undefined;
  employeeId: string;
  companyId: string;
  email?: string;
  sessionId: string;
}

export type Principal = ForemanPrincipal | WorkerPrincipal;

export function isForeman(principal: Principal): principal is ForemanPrincipal {
  return principal.kind === 'user';
}

export function isWorker(principal: Principal): principal is WorkerPrincipal {
  return principal.kind === 'employee';
}

/** Human-readable actor id for logs and audit trails. */
export function principalLabel(principal: Principal): string {
  return isForeman(principal) ? `user:${principal.userId}` : `employee:${principal.employeeId}`;
}
