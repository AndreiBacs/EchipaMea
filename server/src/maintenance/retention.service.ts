import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { TokenService } from '../auth/token.service';
import { WorkerTicketService } from '../auth/worker-ticket.service';
import { AppConfig } from '../common/config/configuration';
import { PrismaService } from '../common/prisma/prisma.service';
import { MediaService } from '../media/media.service';
import { NotificationsService } from '../notifications/notifications.service';
import { RealtimeTicketService } from '../realtime/realtime-ticket.service';
import { TelemetryService } from '../telemetry/telemetry.service';

/** Rows deleted per task; `null` when the task failed (and was logged). */
export type RetentionReport = Record<
  | 'locationSamples'
  | 'refreshTokens'
  | 'workerLoginTickets'
  | 'realtimeTickets'
  | 'unreferencedMedia'
  | 'readNotifications',
  number | null
>;

/**
 * Runs the prune methods every module already has, which until now nothing
 * called: location samples past `LOCATION_SAMPLE_RETENTION_DAYS` (the most
 * sensitive data in the product), spent tickets and refresh tokens, orphaned
 * uploads and old read notifications.
 *
 * In-process on purpose while there is one API instance. With several, set
 * `RETENTION_JOBS_ENABLED=false` on all but one -- every task is idempotent, so
 * an overlap is wasteful rather than harmful.
 */
@Injectable()
export class RetentionService {
  private readonly logger = new Logger(RetentionService.name);

  constructor(
    private readonly config: AppConfig,
    private readonly prisma: PrismaService,
    private readonly telemetry: TelemetryService,
    private readonly tokens: TokenService,
    private readonly workerTickets: WorkerTicketService,
    private readonly realtimeTickets: RealtimeTicketService,
    private readonly media: MediaService,
    private readonly notifications: NotificationsService,
  ) {}

  // 01:00 UTC is 03:00-04:00 in Romania: after the last report of the day and
  // well before the earliest shift start the seed knows about (07:00).
  @Cron('0 1 * * *', { name: 'retention', timeZone: 'UTC' })
  async nightly(): Promise<void> {
    if (!this.config.retentionJobsEnabled) return;
    await this.runOnce();
  }

  /** Runs every task once. Each is isolated: one failure does not skip the rest. */
  async runOnce(): Promise<RetentionReport> {
    const report: RetentionReport = {
      locationSamples: await this.task('locationSamples', () => this.telemetry.pruneOldSamples()),
      refreshTokens: await this.task('refreshTokens', () => this.tokens.pruneExpired()),
      workerLoginTickets: await this.task('workerLoginTickets', () =>
        this.workerTickets.pruneExpired(),
      ),
      realtimeTickets: await this.task('realtimeTickets', () =>
        this.realtimeTickets.pruneExpired(),
      ),
      unreferencedMedia: await this.task('unreferencedMedia', () => this.media.pruneUnreferenced()),
      // Scoped per company by design: notifications are tenant data, and the
      // service will not run an unscoped delete across every tenant.
      readNotifications: await this.task('readNotifications', async () => {
        const companies = await this.prisma.company.findMany({ select: { id: true } });
        let total = 0;
        for (const { id } of companies) total += await this.notifications.pruneRead(id);
        return total;
      }),
    };

    this.logger.log(
      `Retention run: ${Object.entries(report)
        .map(([name, count]) => `${name}=${count ?? 'failed'}`)
        .join(', ')}`,
    );
    return report;
  }

  private async task(name: string, run: () => Promise<number>): Promise<number | null> {
    try {
      return await run();
    } catch (error) {
      this.logger.error(
        `Retention task ${name} failed`,
        error instanceof Error ? error.stack : error,
      );
      return null;
    }
  }
}
