import { HttpStatus, Injectable, Logger } from '@nestjs/common';
import { AppConfig } from '../common/config/configuration';
import { AppException } from '../common/errors/app-exception';
import { ErrorCode } from '../common/errors/error-codes';
import { PrismaService } from '../common/prisma/prisma.service';
import { generateSecret, hashSecret } from '../common/util/ids';
import type { ForemanPrincipal } from '../common/auth/principal';
import type { WorkerLoginTicketDto } from './dto/worker-ticket.dto';
import type { WorkerSessionResponseDto } from './dto/auth.dto';
import { buildQrPayload, parseQrPayload } from './qr-payload';
import { TokenService, type RefreshSubject } from './token.service';

interface RedeemMeta {
  ip?: string;
  userAgent?: string;
}

@Injectable()
export class WorkerTicketService {
  private readonly logger = new Logger(WorkerTicketService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly tokens: TokenService,
    private readonly config: AppConfig,
  ) {}

  /**
   * Mints a QR login ticket for one employee.
   *
   * The secret is generated here and stored only as a sha256 hash. This is the
   * substantive change from the previous client-side scheme, where the phone
   * built `ticket-<employeeId>-<micros>-<hex>` -- roughly 31 bits of entropy
   * around a known employee id and a coarse timestamp, i.e. guessable.
   */
  async issue(principal: ForemanPrincipal, employeeId: string): Promise<WorkerLoginTicketDto> {
    const employee = await this.prisma.employee.findFirst({
      where: { id: employeeId, companyId: principal.companyId, deletedAt: null },
      select: { id: true, name: true, isActive: true },
    });
    if (!employee) throw AppException.notFound('Employee', employeeId);
    if (!employee.isActive) {
      throw AppException.conflict(
        'This employee is not active and cannot sign in.',
        ErrorCode.ACCOUNT_DISABLED,
      );
    }

    const ticketId = generateSecret('tkt_');
    const issuedAt = new Date();
    const ttlSeconds = this.config.workerLoginTicketTtlSeconds;
    const expiresAt = new Date(issuedAt.getTime() + ttlSeconds * 1000);

    await this.prisma.workerLoginTicket.create({
      data: {
        companyId: principal.companyId,
        employeeId: employee.id,
        issuedByUserId: principal.userId,
        ticketHash: hashSecret(ticketId),
        issuedAt,
        expiresAt,
      },
    });

    const payload = buildQrPayload({
      ticketId,
      employeeId: employee.id,
      employeeName: employee.name,
      issuedAt,
      expiresAt,
    });
    const qrPayload = JSON.stringify(payload);

    return {
      ticketId,
      issuedAt: issuedAt.toISOString(),
      expiresAt: expiresAt.toISOString(),
      expiresInSeconds: ttlSeconds,
      qrPayload,
      qrPayloadUrl: this.buildDeepLink(qrPayload),
    };
  }

  /**
   * Exchanges a scanned ticket for a real worker session.
   *
   * Redemption is a single conditional UPDATE so two devices scanning the same
   * printed code cannot both win: whichever statement matches
   * `redeemedAt IS NULL` first claims it, and the other gets a clean 409.
   */
  async redeem(
    input: { ticketId?: string; payload?: string },
    meta: RedeemMeta = {},
  ): Promise<WorkerSessionResponseDto> {
    const ticketId = this.resolveTicketId(input);
    const ticketHash = hashSecret(ticketId);

    const ticket = await this.prisma.workerLoginTicket.findUnique({
      where: { ticketHash },
      select: {
        id: true,
        companyId: true,
        employeeId: true,
        expiresAt: true,
        redeemedAt: true,
        employee: { select: { id: true, name: true, isActive: true, deletedAt: true } },
      },
    });

    if (!ticket) {
      throw ticketNotFound();
    }
    if (ticket.redeemedAt) {
      throw AppException.conflict(
        'This login code has already been used. Ask for a new one.',
        ErrorCode.TICKET_ALREADY_REDEEMED,
      );
    }
    if (ticket.expiresAt.getTime() <= Date.now()) {
      throw AppException.gone(
        'This login code has expired. Ask for a new one.',
        ErrorCode.TICKET_EXPIRED,
      );
    }
    if (!ticket.employee || !ticket.employee.isActive || ticket.employee.deletedAt) {
      throw AppException.forbidden('This worker is no longer active.', ErrorCode.ACCOUNT_DISABLED);
    }

    const claimed = await this.prisma.workerLoginTicket.updateMany({
      where: { companyId: ticket.companyId, ticketHash, redeemedAt: null },
      data: {
        redeemedAt: new Date(),
        redeemedIp: meta.ip ?? null,
        redeemedUserAgent: meta.userAgent ?? null,
      },
    });

    if (claimed.count === 0) {
      // Lost the race against a concurrent scan.
      throw AppException.conflict(
        'This login code has already been used. Ask for a new one.',
        ErrorCode.TICKET_ALREADY_REDEEMED,
      );
    }

    const subject: RefreshSubject = {
      companyId: ticket.companyId,
      role: 'worker',
      employeeId: ticket.employee.id,
    };
    const issued = await this.tokens.issueSession(subject, meta);

    this.logger.log(`Worker ${ticket.employee.id} signed in via QR ticket.`);

    return {
      token: issued.accessToken,
      accessToken: issued.accessToken,
      tokenType: 'Bearer',
      expiresIn: issued.expiresIn,
      refreshToken: issued.refreshToken,
      refreshExpiresIn: issued.refreshExpiresIn,
      worker: {
        employeeId: ticket.employee.id,
        employeeName: ticket.employee.name,
        role: 'worker',
        companyId: ticket.companyId,
      },
    };
  }

  /** Housekeeping: expired tickets have no further use. */
  async pruneExpired(olderThanHours = 24): Promise<number> {
    const cutoff = new Date(Date.now() - olderThanHours * 60 * 60 * 1000);
    const result = await this.prisma.workerLoginTicket.deleteMany({
      where: { expiresAt: { lt: cutoff } },
    });
    return result.count;
  }

  private resolveTicketId(input: { ticketId?: string; payload?: string }): string {
    if (input.ticketId && input.ticketId.trim().length > 0) return input.ticketId.trim();

    const parsed = input.payload ? parseQrPayload(input.payload) : undefined;
    if (!parsed) {
      throw AppException.badRequest(
        'Could not read a login ticket from the scanned code.',
        'payload',
      );
    }
    return parsed.ticketId;
  }

  private buildDeepLink(qrPayload: string): string | undefined {
    const base = this.config.appWorkerLoginUrl;
    if (!base) return undefined;
    const encoded = Buffer.from(qrPayload, 'utf8').toString('base64url');
    const separator = base.includes('?') ? '&' : '?';
    return `${base}${separator}payload=${encoded}`;
  }
}

/**
 * An unknown ticket hash is reported as a plain "not valid" 404 rather than a
 * distinct expired/redeemed status, so a caller cannot probe which ticket ids
 * ever existed.
 */
function ticketNotFound(): AppException {
  return new AppException(
    HttpStatus.NOT_FOUND,
    ErrorCode.TICKET_NOT_FOUND,
    'This login code is not valid.',
  );
}
