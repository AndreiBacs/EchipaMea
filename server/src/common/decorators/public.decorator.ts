import { SetMetadata } from '@nestjs/common';

export const IS_PUBLIC_KEY = 'echipamea:isPublic';

/**
 * Opts a route out of `JwtAuthGuard`.
 *
 * Authentication is global and fail-closed, so this is the only way to expose an
 * endpoint. Keep the list short: login, ticket redeem, health. Everything else
 * must present a token that names a company -- there is no anonymous principal
 * to fall back to.
 */
export const Public = () => SetMetadata(IS_PUBLIC_KEY, true);
