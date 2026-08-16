import { Injectable, Logger } from '@nestjs/common';
import { AppConfig } from '../common/config/configuration';
import { AppException } from '../common/errors/app-exception';
import { ErrorCode } from '../common/errors/error-codes';
import { PrismaService } from '../common/prisma/prisma.service';
import { generateSecret, hashSecret } from '../common/util/ids';
import type { Principal } from '../common/auth/principal';
import { PrincipalResolverService } from '../auth/principal-resolver.service';

export interface RealtimeTicketDto {
  ticket: string;
  expiresAt: string;
  expiresInSeconds: number;
  /**
   * Channel paths, so the client never has to hardcode them. Full URLs are the
   * client's job: it already holds the host.
   */
  channels: { workerTelemetry: string; foremanNotifications: string };
}

export const WS_PATHS = {
  workerTelemetry: '/ws/worker-telemetry',
  foremanNotifications: '/ws/foreman-notifications',
} as const;

/**
 * Short-lived, single-use credentials for the WebSocket handshake.
 *
 * A query parameter is the only place a browser can put credentials on a
 * WebSocket: Dart's `WebSocketChannel.connect` cannot set headers on web. Query
 * strings land in access logs and proxy logs, which is exactly why this is a
 * one-shot 60-second ticket and not the access token.
 */
@Injectable()
export class RealtimeTicketService {
  private readonly logger = new Logger(RealtimeTicketService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly principals: PrincipalResolverService,
    private readonly config: AppConfig,
  ) {}

  async issue(principal: Principal): Promise<RealtimeTicketDto> {
    const ticket = generateSecret('rtt_');
    const ttlSeconds = this.config.realtimeTicketTtlSeconds;
    const expiresAt = new Date(Date.now() + ttlSeconds * 1000);

    await this.prisma.realtimeTicket.create({
      data: {
        companyId: principal.companyId,
        ticketHash: hashSecret(ticket),
        role: principal.role,
        userId: principal.userId ?? null,
        employeeId: principal.employeeId ?? null,
        expiresAt,
      },
    });

    return {
      ticket,
      expiresAt: expiresAt.toISOString(),
      expiresInSeconds: ttlSeconds,
      channels: { ...WS_PATHS },
    };
  }

  /**
   * Redeems a ticket exactly once.
   *
   * Single-use means a client fetches a ticket per connection attempt, including
   * every reconnect. That is one extra HTTP round trip on a reconnect and it
   * buys a credential that is worthless the moment it has been used, even if it
   * is sitting in a proxy log.
   */
  async consume(ticket: string): Promise<Principal> {
    const ticketHash = hashSecret(ticket);

    const row = await this.prisma.realtimeTicket.findUnique({
      where: { ticketHash },
      select: {
        id: true,
        companyId: true,
        role: true,
        userId: true,
        employeeId: true,
        expiresAt: true,
        usedAt: true,
      },
    });

    if (!row) {
      throw AppException.unauthenticated(
        'This realtime ticket is not valid.',
        ErrorCode.TICKET_NOT_FOUND,
      );
    }
    if (row.expiresAt.getTime() <= Date.now()) {
      throw AppException.unauthenticated(
        'This realtime ticket has expired.',
        ErrorCode.TICKET_EXPIRED,
      );
    }

    // Conditional claim, so two parallel handshakes cannot both win.
    const claimed = await this.prisma.realtimeTicket.updateMany({
      where: { id: row.id, usedAt: null },
      data: { usedAt: new Date() },
    });
    if (claimed.count === 0) {
      throw AppException.unauthenticated(
        'This realtime ticket has already been used.',
        ErrorCode.TICKET_ALREADY_REDEEMED,
      );
    }

    return this.principals.fromSubject({
      companyId: row.companyId,
      role: normaliseRole(row.role),
      userId: row.userId,
      employeeId: row.employeeId,
    });
  }

  /** Housekeeping: a used or expired ticket has no further purpose. */
  async pruneExpired(olderThanHours = 6): Promise<number> {
    const cutoff = new Date(Date.now() - olderThanHours * 60 * 60 * 1000);
    const result = await this.prisma.realtimeTicket.deleteMany({
      where: { expiresAt: { lt: cutoff } },
    });
    if (result.count > 0) {
      this.logger.debug(`Pruned ${result.count} expired realtime ticket(s).`);
    }
    return result.count;
  }
}

/** The column is a plain string; anything unexpected degrades to the least privilege. */
function normaliseRole(role: string): 'admin' | 'foreman' | 'worker' {
  if (role === 'admin' || role === 'foreman') return role;
  return 'worker';
}
