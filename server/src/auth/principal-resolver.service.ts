import { Injectable } from '@nestjs/common';
import { AppException } from '../common/errors/app-exception';
import { ErrorCode } from '../common/errors/error-codes';
import { PrismaService } from '../common/prisma/prisma.service';
import { newSessionId } from '../common/util/ids';
import type { Principal } from '../common/auth/principal';
import { PrincipalCache } from './guards/principal-cache';
import { TokenService } from './token.service';

/** The subject of a realtime ticket, which carries no JWT claims of its own. */
export interface SubjectRef {
  companyId: string;
  role: 'admin' | 'foreman' | 'worker';
  userId?: string | null;
  employeeId?: string | null;
  sessionId?: string | null;
}

/**
 * Turns verified credentials into a `Principal`.
 *
 * Extracted from `JwtAuthGuard` so the WebSocket handshake resolves identity the
 * same way an HTTP request does. Two copies of "is this worker still employed"
 * would be one copy too many -- a socket lives for hours, so it is exactly where
 * a stale answer would matter most.
 */
@Injectable()
export class PrincipalResolverService {
  private readonly cache = new PrincipalCache();

  constructor(
    private readonly prisma: PrismaService,
    private readonly tokens: TokenService,
  ) {}

  /**
   * Re-checks that a token's subject still exists and is enabled.
   *
   * A JWT stays cryptographically valid until it expires, so a fired worker
   * would otherwise keep full access for up to 12 hours. Cached briefly to keep
   * this off the hot path.
   */
  async fromClaims(claims: {
    role: 'admin' | 'foreman' | 'worker';
    companyId: string;
    sub: string;
    sid: string;
    userId?: string;
    employeeId?: string;
    email?: string;
  }): Promise<Principal> {
    const cacheKey = `${claims.companyId}:${claims.sid}:${claims.sub}`;
    const cached = this.cache.get(cacheKey);
    if (cached) return cached;

    if (await this.tokens.isSessionRevoked(claims.companyId, claims.sid)) {
      throw AppException.unauthenticated('This session has been revoked.', ErrorCode.TOKEN_INVALID);
    }

    const principal = await this.fromSubject({
      companyId: claims.companyId,
      role: claims.role,
      userId: claims.userId ?? (claims.role === 'worker' ? undefined : claims.sub),
      employeeId: claims.employeeId ?? (claims.role === 'worker' ? claims.sub : undefined),
      sessionId: claims.sid,
    });

    this.cache.set(cacheKey, principal);
    return principal;
  }

  /**
   * Resolves an identity that was established by something other than a JWT --
   * today, a redeemed realtime ticket.
   *
   * Session revocation is *not* re-checked here. A realtime ticket is minted by
   * an authenticated HTTP call that already ran the full guard chain seconds
   * earlier, so the check would be re-running a fresh answer. What this does not
   * cover is revocation *after* the socket is open; closing live sockets on
   * logout is deferred (see RealtimeTicketService).
   */
  async fromSubject(subject: SubjectRef): Promise<Principal> {
    const sessionId = subject.sessionId ?? newSessionId();

    if (subject.role === 'worker') {
      const employeeId = subject.employeeId ?? '';
      const employee = await this.prisma.employee.findFirst({
        where: { id: employeeId, companyId: subject.companyId, deletedAt: null },
        select: { id: true, isActive: true },
      });
      if (!employee || !employee.isActive) {
        throw AppException.forbidden(
          'This worker is no longer active.',
          ErrorCode.ACCOUNT_DISABLED,
        );
      }
      return {
        kind: 'employee',
        role: 'worker',
        employeeId: employee.id,
        companyId: subject.companyId,
        sessionId,
      };
    }

    const userId = subject.userId ?? '';
    const user = await this.prisma.user.findFirst({
      where: { id: userId, companyId: subject.companyId, deletedAt: null },
      select: { id: true, email: true, role: true, isActive: true },
    });
    if (!user || !user.isActive) {
      throw AppException.forbidden('This account is disabled.', ErrorCode.ACCOUNT_DISABLED);
    }
    return {
      kind: 'user',
      role: user.role === 'admin' ? 'admin' : 'foreman',
      userId: user.id,
      companyId: subject.companyId,
      email: user.email,
      sessionId,
    };
  }
}
