import type { PrincipalRole } from '../common/auth/principal';

/**
 * Access-token payload.
 *
 * `sub` alone is ambiguous because foremen (`User`) and workers (`Employee`)
 * live in different id spaces, so the concrete id is always also present under
 * an explicit claim. Nothing in the codebase has to guess.
 */
export interface JwtClaims {
  iss: string;
  aud: string;
  sub: string;
  role: PrincipalRole;
  companyId: string;
  userId?: string;
  employeeId?: string;
  email?: string;
  /** Session / refresh-token family id. Revoking the family kills the session. */
  sid: string;
  jti: string;
  iat: number;
  exp: number;
}

export type JwtClaimsInput = Omit<JwtClaims, 'iss' | 'aud' | 'iat' | 'exp' | 'jti'>;

export function isJwtClaims(value: unknown): value is JwtClaims {
  if (typeof value !== 'object' || value === null) return false;
  const c = value as Partial<JwtClaims>;
  return (
    typeof c.sub === 'string' &&
    typeof c.companyId === 'string' &&
    typeof c.sid === 'string' &&
    (c.role === 'admin' || c.role === 'foreman' || c.role === 'worker')
  );
}
