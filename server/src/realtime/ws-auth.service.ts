import { Injectable, Logger } from '@nestjs/common';
import type { IncomingMessage } from 'node:http';
import { AppConfig } from '../common/config/configuration';
import { AppException } from '../common/errors/app-exception';
import type { Principal } from '../common/auth/principal';
import { PrincipalResolverService } from '../auth/principal-resolver.service';
import { TokenService } from '../auth/token.service';
import { RealtimeTicketService } from './realtime-ticket.service';

/**
 * Decides who is on the other end of a WebSocket upgrade.
 *
 * Four routes, in descending order of preference:
 *
 *   1. `?ticket=` -- single-use, 60s. The intended path, and the only one that
 *      works from Flutter web, where headers cannot be set on a WebSocket.
 *   2. `Authorization: Bearer` -- available to native clients and to tests.
 *   3. `?token=` -- the access token in the query string. Gated behind
 *      REALTIME_ACCESS_TOKEN_IN_QUERY because it leaks into access logs; it
 *      exists so the client can be rewired before the ticket flow ships.
 *   4. Anonymous -- gated behind REALTIME_ALLOW_ANONYMOUS. The current app sends
 *      no credentials at all, so without this the migration would have to land
 *      on both sides in the same release.
 */
@Injectable()
export class WsAuthService {
  private readonly logger = new Logger(WsAuthService.name);

  constructor(
    private readonly tickets: RealtimeTicketService,
    private readonly tokens: TokenService,
    private readonly principals: PrincipalResolverService,
    private readonly config: AppConfig,
  ) {}

  async authenticate(request: IncomingMessage): Promise<Principal> {
    const query = readQuery(request);

    const ticket = query.get('ticket');
    if (ticket) return this.tickets.consume(ticket);

    const bearer = readBearer(request);
    if (bearer) return this.fromAccessToken(bearer);

    const queryToken = query.get('token') ?? query.get('access_token');
    if (queryToken) {
      if (!this.config.realtimeAccessTokenInQuery) {
        throw AppException.unauthenticated(
          'Access tokens are not accepted in the query string. Use POST /realtime/tickets.',
        );
      }
      return this.fromAccessToken(queryToken);
    }

    if (this.config.realtimeAllowAnonymous) {
      return this.principals.anonymous();
    }

    throw AppException.unauthenticated('This socket requires a realtime ticket.');
  }

  private async fromAccessToken(token: string): Promise<Principal> {
    const claims = this.tokens.verifyAccessToken(token);
    return this.principals.fromClaims(claims);
  }
}

function readQuery(request: IncomingMessage): URLSearchParams {
  try {
    // The host is irrelevant; only the query is read. A placeholder keeps this
    // working behind proxies that drop or rewrite the Host header.
    const url = new URL(request.url ?? '/', 'ws://placeholder');
    return url.searchParams;
  } catch {
    return new URLSearchParams();
  }
}

function readBearer(request: IncomingMessage): string | undefined {
  const header = request.headers.authorization;
  if (!header) return undefined;
  const [scheme, value] = header.split(' ');
  if (!scheme || !value) return undefined;
  if (scheme.toLowerCase() !== 'bearer') return undefined;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : undefined;
}
