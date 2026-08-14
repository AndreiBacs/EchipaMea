import { SetMetadata } from '@nestjs/common';

export const IS_PUBLIC_KEY = 'echipamea:isPublic';

/**
 * Opts a route out of `JwtAuthGuard`.
 *
 * Authentication is global and fail-closed, so this is the only way to expose
 * an endpoint. Keep the list short: login, ticket redeem, health.
 */
export const Public = () => SetMetadata(IS_PUBLIC_KEY, true);

export const ALLOW_ANONYMOUS_WORKER_KEY = 'echipamea:allowAnonymousWorker';

/**
 * Marks a route that may run without a token *while the transition flag
 * `ALLOW_ANONYMOUS_WORKER_REPORTS` is on*, attributing the call to the default
 * tenant. Exists solely so the un-rewired Flutter client keeps working; once it
 * sends bearer tokens, the flag goes off and this becomes inert.
 */
export const AllowAnonymousWorker = () => SetMetadata(ALLOW_ANONYMOUS_WORKER_KEY, true);
