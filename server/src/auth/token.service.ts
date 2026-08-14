import { Injectable, Logger } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ulid } from 'ulid';
import { AppConfig } from '../common/config/configuration';
import { AppException } from '../common/errors/app-exception';
import { ErrorCode } from '../common/errors/error-codes';
import { PrismaService } from '../common/prisma/prisma.service';
import { generateSecret, hashSecret, newSessionId } from '../common/util/ids';
import { isJwtClaims, type JwtClaims, type JwtClaimsInput } from './jwt-claims';

export interface IssuedTokens {
  accessToken: string;
  expiresIn: number;
  refreshToken: string;
  refreshExpiresIn: number;
  sessionId: string;
}

export interface RefreshSubject {
  companyId: string;
  role: 'admin' | 'foreman' | 'worker';
  userId?: string;
  employeeId?: string;
  email?: string;
}

interface RequestMeta {
  ip?: string;
  userAgent?: string;
}

@Injectable()
export class TokenService {
  private readonly logger = new Logger(TokenService.name);

  constructor(
    private readonly jwt: JwtService,
    private readonly config: AppConfig,
    private readonly prisma: PrismaService,
  ) {}

  // --- Access tokens -------------------------------------------------------

  signAccessToken(input: JwtClaimsInput): { token: string; expiresIn: number } {
    const ttl = input.role === 'worker' ? this.config.workerAccessTtl : this.config.foremanAccessTtl;
    // Normalised to seconds rather than passed through as "60m": jsonwebtoken's
    // string form is a narrower literal type than our config value.
    const expiresIn = ttlToSeconds(ttl);
    const token = this.jwt.sign(
      { ...input, jti: ulid() },
      {
        algorithm: this.config.jwtAlg,
        secret: this.config.jwtSigningKey,
        issuer: this.config.jwtIssuer,
        audience: this.config.jwtAudience,
        expiresIn,
      },
    );
    return { token, expiresIn };
  }

  /**
   * Verifies an access token.
   *
   * Expiry is reported as its own code because the client's refresh flow keys
   * off `TOKEN_EXPIRED` -- collapsing it into a generic 401 would make every
   * expiry look like a hard logout.
   */
  verifyAccessToken(token: string): JwtClaims {
    let payload: unknown;
    try {
      payload = this.jwt.verify(token, {
        algorithms: [this.config.jwtAlg],
        secret: this.config.jwtVerificationKey,
        issuer: this.config.jwtIssuer,
        audience: this.config.jwtAudience,
      });
    } catch (error) {
      if (isExpiredError(error)) {
        throw AppException.unauthenticated('Access token has expired.', ErrorCode.TOKEN_EXPIRED);
      }
      throw AppException.unauthenticated('Access token is invalid.', ErrorCode.TOKEN_INVALID);
    }

    if (!isJwtClaims(payload)) {
      throw AppException.unauthenticated('Access token is missing required claims.', ErrorCode.TOKEN_INVALID);
    }
    return payload;
  }

  // --- Refresh tokens ------------------------------------------------------

  /**
   * Issues a fresh access + refresh pair, starting a new rotation family.
   */
  async issueSession(subject: RefreshSubject, meta: RequestMeta = {}): Promise<IssuedTokens> {
    const sessionId = newSessionId();
    return this.issueForSession(subject, sessionId, meta);
  }

  private async issueForSession(
    subject: RefreshSubject,
    sessionId: string,
    meta: RequestMeta,
  ): Promise<IssuedTokens> {
    const { token: accessToken, expiresIn } = this.signAccessToken({
      sub: subject.userId ?? subject.employeeId ?? '',
      role: subject.role,
      companyId: subject.companyId,
      userId: subject.userId,
      employeeId: subject.employeeId,
      email: subject.email,
      sid: sessionId,
    });

    const days =
      subject.role === 'worker'
        ? this.config.workerRefreshTtlDays
        : this.config.foremanRefreshTtlDays;
    const refreshExpiresIn = days * 24 * 60 * 60;
    const refreshSecret = generateSecret('rt_');

    await this.prisma.refreshToken.create({
      data: {
        companyId: subject.companyId,
        userId: subject.userId ?? null,
        employeeId: subject.employeeId ?? null,
        tokenHash: hashSecret(refreshSecret),
        familyId: sessionId,
        expiresAt: new Date(Date.now() + refreshExpiresIn * 1000),
        ip: meta.ip ?? null,
        userAgent: meta.userAgent ?? null,
      },
    });

    return {
      accessToken,
      expiresIn,
      refreshToken: refreshSecret,
      refreshExpiresIn,
      sessionId,
    };
  }

  /**
   * Exchanges a refresh token for a new pair, rotating the old one out.
   *
   * Presenting an already-rotated token means the secret leaked -- either an
   * attacker is replaying it or the legitimate client is, and we cannot tell
   * which -- so the entire family is revoked and both parties must log in again.
   */
  async rotate(refreshToken: string, meta: RequestMeta = {}): Promise<IssuedTokens> {
    const tokenHash = hashSecret(refreshToken);
    const existing = await this.prisma.refreshToken.findUnique({
      where: { tokenHash },
      include: {
        user: { select: { id: true, email: true, role: true, isActive: true, deletedAt: true } },
        employee: { select: { id: true, isActive: true, deletedAt: true } },
      },
    });

    if (!existing) {
      throw AppException.unauthenticated('Refresh token is invalid.', ErrorCode.TOKEN_INVALID);
    }

    if (existing.revokedAt) {
      this.logger.warn(
        `Refresh token reuse detected for family ${existing.familyId}; revoking the family.`,
      );
      await this.revokeFamily(existing.companyId, existing.familyId);
      throw AppException.unauthenticated(
        'Refresh token has already been used. Please sign in again.',
        ErrorCode.TOKEN_REUSED,
      );
    }

    if (existing.expiresAt.getTime() <= Date.now()) {
      throw AppException.unauthenticated('Refresh token has expired.', ErrorCode.TOKEN_EXPIRED);
    }

    const subject = this.subjectFrom(existing);

    const issued = await this.issueForSession(subject, existing.familyId, meta);

    await this.prisma.refreshToken.update({
      where: { tokenHash },
      data: { revokedAt: new Date(), replacedById: issued.sessionId },
    });

    return issued;
  }

  private subjectFrom(row: {
    companyId: string;
    user: { id: string; email: string; role: string; isActive: boolean; deletedAt: Date | null } | null;
    employee: { id: string; isActive: boolean; deletedAt: Date | null } | null;
  }): RefreshSubject {
    if (row.user) {
      if (!row.user.isActive || row.user.deletedAt) {
        throw AppException.forbidden('This account is disabled.', ErrorCode.ACCOUNT_DISABLED);
      }
      return {
        companyId: row.companyId,
        role: row.user.role === 'admin' ? 'admin' : 'foreman',
        userId: row.user.id,
        email: row.user.email,
      };
    }

    if (row.employee) {
      if (!row.employee.isActive || row.employee.deletedAt) {
        throw AppException.forbidden('This worker is no longer active.', ErrorCode.ACCOUNT_DISABLED);
      }
      return { companyId: row.companyId, role: 'worker', employeeId: row.employee.id };
    }

    throw AppException.unauthenticated('Refresh token has no subject.', ErrorCode.TOKEN_INVALID);
  }

  /** Revokes every token in a session family. Used by logout and reuse detection. */
  async revokeFamily(companyId: string, familyId: string): Promise<void> {
    await this.prisma.refreshToken.updateMany({
      where: { companyId, familyId, revokedAt: null },
      data: { revokedAt: new Date() },
    });
  }

  /** Revokes every session belonging to one principal (e.g. on soft delete). */
  async revokeAllForSubject(
    companyId: string,
    subject: { userId?: string; employeeId?: string },
  ): Promise<void> {
    if (!subject.userId && !subject.employeeId) return;
    await this.prisma.refreshToken.updateMany({
      where: {
        companyId,
        revokedAt: null,
        ...(subject.userId ? { userId: subject.userId } : {}),
        ...(subject.employeeId ? { employeeId: subject.employeeId } : {}),
      },
      data: { revokedAt: new Date() },
    });
  }

  /** True when the session family has been revoked. */
  async isSessionRevoked(companyId: string, sessionId: string): Promise<boolean> {
    const live = await this.prisma.refreshToken.count({
      where: { companyId, familyId: sessionId, revokedAt: null },
    });
    return live === 0;
  }

  /** Housekeeping: drop refresh tokens that expired a while ago. */
  async pruneExpired(olderThanDays = 7): Promise<number> {
    const cutoff = new Date(Date.now() - olderThanDays * 24 * 60 * 60 * 1000);
    const result = await this.prisma.refreshToken.deleteMany({
      where: { expiresAt: { lt: cutoff } },
    });
    return result.count;
  }
}

function isExpiredError(error: unknown): boolean {
  return (
    typeof error === 'object' &&
    error !== null &&
    (error as { name?: string }).name === 'TokenExpiredError'
  );
}

/** Converts a `zeit/ms` style TTL ("60m", "12h") into seconds. */
export function ttlToSeconds(ttl: string): number {
  const match = /^(\d+)\s*(s|m|h|d)?$/.exec(ttl.trim());
  if (!match) return 3600;
  const value = Number(match[1]);
  switch (match[2]) {
    case 'd':
      return value * 86_400;
    case 'h':
      return value * 3_600;
    case 'm':
      return value * 60;
    case 's':
    case undefined:
    default:
      return value;
  }
}
