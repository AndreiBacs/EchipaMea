import { SetMetadata } from '@nestjs/common';
import type { PrincipalRole } from '../auth/principal';

export const ROLES_KEY = 'echipamea:roles';

/**
 * Restricts a route to the listed roles.
 *
 * `RolesGuard` is fail-closed: an unannotated route is foreman/admin only, so
 * a newly added controller is never accidentally reachable by a worker token.
 * Worker-facing routes must therefore opt in explicitly with `@Roles('worker')`.
 */
export const Roles = (...roles: PrincipalRole[]) => SetMetadata(ROLES_KEY, roles);
