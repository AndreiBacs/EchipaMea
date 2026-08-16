import { Injectable } from '@nestjs/common';
import type { IncomingMessage } from 'node:http';
import { AppException } from '../common/errors/app-exception';
import type { Principal } from '../common/auth/principal';
import { PrincipalResolverService } from '../auth/principal-resolver.service';
import { TokenService } from '../auth/token.service';
import { RealtimeTicketService } from './realtime-ticket.service';

/**
 * Decides who is on the other end of a WebSocket upgrade.
 *
 * Two routes, and no third:
 *
 *   1. `?ticket=` -- single-use, 60s, from `POST /realtime/tickets`. The normal
 *      path, and the only one available to Flutter web, where Dart cannot set
 *      headers on a WebSocket.
 *   2. `Authorization: Bearer` -- native clients and tests, which can.
 *
 * A raw access token in the query string used to be accepted behind a flag. It
 * is not any more: query strings land in proxy and access logs, and a ticket
 * costs one HTTP round trip to avoid that. Nor is there an anonymous route --
 * every socket belongs to a company because the credential says so.
 */
@Injectable()
export class WsAuthService {
  constructor(
    private readonly tickets: RealtimeTicketService,
    private readonly tokens: TokenService,
    private readonly principals: PrincipalResolverService,
  ) {}

  async authenticate(request: IncomingMessage): Promise<Principal> {
    const query = readQuery(request);

    const ticket = query.get('ticket');
    if (ticket) return this.tickets.consume(ticket);

    const bearer = readBearer(request);
    if (bearer) return this.fromAccessToken(bearer);

    if (query.get('token') ?? query.get('access_token')) {
      throw AppException.unauthenticated(
        'Access tokens are not accepted in the query string. Use POST /realtime/tickets.',
      );
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
