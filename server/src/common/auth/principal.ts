/**
 * Who is making the current request.
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

/**
 * Unauthenticated traffic accepted only while the migration transition flags
 * are on. It carries no verified identity: everything it claims about itself
 * is taken at face value, and it is attributed to the default tenant.
 */
export interface AnonymousPrincipal {
  kind: 'anonymous';
  role: 'worker';
  userId?: undefined;
  employeeId?: string;
  companyId: string;
  sessionId: string;
}

export type Principal = ForemanPrincipal | WorkerPrincipal | AnonymousPrincipal;

export function isForeman(principal: Principal): principal is ForemanPrincipal {
  return principal.kind === 'user';
}

export function isWorker(principal: Principal): principal is WorkerPrincipal {
  return principal.kind === 'employee';
}

export function isAnonymous(principal: Principal): principal is AnonymousPrincipal {
  return principal.kind === 'anonymous';
}

/** Human-readable actor id for logs and audit trails. */
export function principalLabel(principal: Principal): string {
  if (isForeman(principal)) return `user:${principal.userId}`;
  if (isWorker(principal)) return `employee:${principal.employeeId}`;
  return `anonymous:${principal.employeeId ?? 'unknown'}`;
}
