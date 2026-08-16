import { Injectable, Logger } from '@nestjs/common';
import { AppException } from '../common/errors/app-exception';
import { ErrorCode } from '../common/errors/error-codes';
import { PrismaService } from '../common/prisma/prisma.service';
import type { ForemanPrincipal, Principal } from '../common/auth/principal';
import type { CurrentPrincipalDto, LoginResponseDto } from './dto/auth.dto';
import { PasswordService } from './password.service';
import { TokenService } from './token.service';

export interface RequestMeta {
  ip?: string;
  userAgent?: string;
}

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly passwords: PasswordService,
    private readonly tokens: TokenService,
  ) {}

  async loginForeman(
    email: string,
    password: string,
    meta: RequestMeta = {},
  ): Promise<LoginResponseDto> {
    const normalisedEmail = email.trim().toLowerCase();

    const user = await this.prisma.user.findUnique({
      where: { email: normalisedEmail },
      select: {
        id: true,
        companyId: true,
        email: true,
        passwordHash: true,
        role: true,
        fullName: true,
        isActive: true,
        deletedAt: true,
      },
    });

    // Spend the same time whether or not the account exists, so response
    // latency cannot be used to enumerate registered emails.
    if (!user) {
      await this.passwords.wasteTime(password);
      throw AppException.unauthenticated(
        'Invalid email or password.',
        ErrorCode.INVALID_CREDENTIALS,
      );
    }

    const valid = await this.passwords.verify(user.passwordHash, password);
    if (!valid) {
      throw AppException.unauthenticated(
        'Invalid email or password.',
        ErrorCode.INVALID_CREDENTIALS,
      );
    }

    // Deliberately checked after password verification: reporting "disabled"
    // to an unauthenticated caller would confirm the account exists.
    if (!user.isActive || user.deletedAt) {
      throw AppException.forbidden('This account is disabled.', ErrorCode.ACCOUNT_DISABLED);
    }

    if (this.passwords.needsRehash(user.passwordHash)) {
      const rehashed = await this.passwords.hash(password);
      await this.prisma.user.update({
        where: { id_companyId: { id: user.id, companyId: user.companyId } },
        data: { passwordHash: rehashed },
      });
      this.logger.log(`Rehashed password for user ${user.id} under current parameters.`);
    }

    const issued = await this.tokens.issueSession(
      {
        companyId: user.companyId,
        role: user.role === 'admin' ? 'admin' : 'foreman',
        userId: user.id,
        email: user.email,
      },
      meta,
    );

    await this.prisma.user.update({
      where: { id_companyId: { id: user.id, companyId: user.companyId } },
      data: { lastLoginAt: new Date() },
    });

    return {
      // `token` and `accessToken` carry the same value: the current client
      // reads `data['token'] ?? data['accessToken']`, and the draft spec's
      // anyOf allowed either. Emitting both means zero client change on day one.
      token: issued.accessToken,
      accessToken: issued.accessToken,
      tokenType: 'Bearer',
      expiresIn: issued.expiresIn,
      refreshToken: issued.refreshToken,
      refreshExpiresIn: issued.refreshExpiresIn,
      user: {
        id: user.id,
        email: user.email,
        role: user.role,
        companyId: user.companyId,
        fullName: user.fullName,
      },
    };
  }

  async refresh(refreshToken: string, meta: RequestMeta = {}): Promise<LoginResponseDto> {
    const issued = await this.tokens.rotate(refreshToken, meta);
    const claims = this.tokens.verifyAccessToken(issued.accessToken);

    let user = {
      id: claims.userId ?? claims.sub,
      email: claims.email ?? '',
      role: claims.role,
      companyId: claims.companyId,
      fullName: '',
    };

    if (claims.role !== 'worker') {
      const row = await this.prisma.user.findFirst({
        where: { id: user.id, companyId: claims.companyId },
        select: { id: true, email: true, role: true, fullName: true },
      });
      if (row) {
        user = { ...user, email: row.email, role: row.role, fullName: row.fullName };
      }
    }

    return {
      token: issued.accessToken,
      accessToken: issued.accessToken,
      tokenType: 'Bearer',
      expiresIn: issued.expiresIn,
      refreshToken: issued.refreshToken,
      refreshExpiresIn: issued.refreshExpiresIn,
      user,
    };
  }

  /** Revokes the caller's session family. Idempotent. */
  async logout(principal: Principal): Promise<void> {
    await this.tokens.revokeFamily(principal.companyId, principal.sessionId);
  }

  async changePassword(
    principal: ForemanPrincipal,
    currentPassword: string,
    newPassword: string,
  ): Promise<void> {
    const user = await this.prisma.user.findFirst({
      where: { id: principal.userId, companyId: principal.companyId, deletedAt: null },
      select: { id: true, passwordHash: true },
    });
    if (!user) throw AppException.notFound('User', principal.userId);

    const valid = await this.passwords.verify(user.passwordHash, currentPassword);
    if (!valid) {
      throw AppException.badRequest('Current password is incorrect.', 'currentPassword');
    }

    await this.prisma.user.update({
      where: { id_companyId: { id: user.id, companyId: principal.companyId } },
      data: { passwordHash: await this.passwords.hash(newPassword) },
    });

    // A password change should end other sessions; the caller re-authenticates.
    await this.tokens.revokeAllForSubject(principal.companyId, { userId: user.id });
  }

  async describePrincipal(principal: Principal): Promise<CurrentPrincipalDto> {
    if (principal.kind === 'user') {
      const user = await this.prisma.user.findFirst({
        where: { id: principal.userId, companyId: principal.companyId },
        select: { email: true, fullName: true },
      });
      return {
        role: principal.role,
        companyId: principal.companyId,
        userId: principal.userId,
        email: user?.email ?? principal.email,
        displayName: user?.fullName || (user?.email ?? principal.email),
      };
    }

    const employee = await this.prisma.employee.findFirst({
      where: { id: principal.employeeId, companyId: principal.companyId },
      select: { name: true, email: true },
    });
    return {
      role: 'worker',
      companyId: principal.companyId,
      employeeId: principal.employeeId,
      email: employee?.email || undefined,
      displayName: employee?.name ?? 'Worker',
    };
  }
}
