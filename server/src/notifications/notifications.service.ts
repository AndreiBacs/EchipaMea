import { Injectable, Logger } from '@nestjs/common';
import type { Prisma } from '@prisma/client';
import { AppException } from '../common/errors/app-exception';
import { PrismaService } from '../common/prisma/prisma.service';
import {
  buildPage,
  cursorFilter,
  encodeCursor,
  parseDateSortKey,
  type Paged,
} from '../common/dto/page.dto';
import type { ForemanPrincipal } from '../common/auth/principal';
import type {
  MarkAllReadResultDto,
  NotificationDto,
  NotificationListQuery,
  PagedNotificationsDto,
} from './dto/notification.dto';

type NotificationRow = Prisma.NotificationGetPayload<object>;

/**
 * Notifications are stored one row per recipient, not one row per event.
 *
 * Read state is per person: a job with three foremen means three rows, and one
 * of them opening the app must not clear the badge on the other two phones.
 * The reports and arrivals paths already fan out that way.
 */
@Injectable()
export class NotificationsService {
  private readonly logger = new Logger(NotificationsService.name);

  constructor(private readonly prisma: PrismaService) {}

  async list(
    principal: ForemanPrincipal,
    query: NotificationListQuery,
  ): Promise<PagedNotificationsDto> {
    const where: Prisma.NotificationWhereInput = {
      companyId: principal.companyId,
      recipientUserId: principal.userId,
      ...(query.unreadOnly ? { readAt: null } : {}),
      ...(query.kind ? { kind: query.kind } : {}),
    };

    // Newest first, which is the only order a notification list is ever read in.
    const resume = cursorFilter({
      sortField: 'createdAt',
      descending: true,
      cursor: query.cursor,
      parseSortKey: parseDateSortKey,
    });
    if (resume) where.AND = [{ OR: resume }];

    const rows = await this.prisma.notification.findMany({
      where,
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take: query.limit + 1,
    });

    const total = query.withTotal ? await this.prisma.notification.count({ where }) : undefined;

    const page: Paged<NotificationRow> = buildPage(
      rows,
      query.limit,
      (row) => encodeCursor(row.createdAt.toISOString(), row.id),
      total,
    );

    // Counted independently of the page filter: the badge means "unread in
    // total", not "unread among the rows you happen to be looking at".
    const unreadCount = await this.unreadCount(principal);

    return {
      items: page.items.map(toNotificationDto),
      page: page.page,
      unreadCount,
    };
  }

  async unreadCount(principal: ForemanPrincipal): Promise<number> {
    return this.prisma.notification.count({
      where: {
        companyId: principal.companyId,
        recipientUserId: principal.userId,
        readAt: null,
      },
    });
  }

  /**
   * Marks one notification read.
   *
   * Scoped to the recipient as well as the tenant, so a foreman cannot mark a
   * colleague's copy read. Already-read rows keep their original `readAt`
   * rather than being stamped again -- the first read is the interesting one.
   */
  async markRead(principal: ForemanPrincipal, notificationId: string): Promise<NotificationDto> {
    const existing = await this.prisma.notification.findFirst({
      where: {
        id: notificationId,
        companyId: principal.companyId,
        recipientUserId: principal.userId,
      },
    });
    if (!existing) throw AppException.notFound('Notification', notificationId);

    if (existing.readAt) return toNotificationDto(existing);

    const updated = await this.prisma.notification.update({
      where: { id: notificationId },
      data: { readAt: new Date() },
    });
    return toNotificationDto(updated);
  }

  /** Marks one back to unread, so a foreman can flag something to return to. */
  async markUnread(principal: ForemanPrincipal, notificationId: string): Promise<NotificationDto> {
    const existing = await this.prisma.notification.findFirst({
      where: {
        id: notificationId,
        companyId: principal.companyId,
        recipientUserId: principal.userId,
      },
      select: { id: true },
    });
    if (!existing) throw AppException.notFound('Notification', notificationId);

    const updated = await this.prisma.notification.update({
      where: { id: notificationId },
      data: { readAt: null },
    });
    return toNotificationDto(updated);
  }

  async markAllRead(principal: ForemanPrincipal): Promise<MarkAllReadResultDto> {
    const result = await this.prisma.notification.updateMany({
      where: {
        companyId: principal.companyId,
        recipientUserId: principal.userId,
        readAt: null,
      },
      data: { readAt: new Date() },
    });
    return { updated: result.count, unreadCount: 0 };
  }

  /** Housekeeping: read notifications past their useful life. */
  async pruneRead(companyId: string, olderThanDays = 90): Promise<number> {
    const cutoff = new Date(Date.now() - olderThanDays * 24 * 60 * 60 * 1000);
    const result = await this.prisma.notification.deleteMany({
      where: { companyId, readAt: { not: null, lt: cutoff } },
    });
    if (result.count > 0) {
      this.logger.log(`Pruned ${result.count} read notification(s) older than ${olderThanDays}d.`);
    }
    return result.count;
  }
}

function toNotificationDto(row: NotificationRow): NotificationDto {
  return {
    id: row.id,
    kind: row.kind,
    // Prisma types Json as `JsonValue`; the column is always written as an
    // object by the services that create these rows.
    payload: (row.payload ?? {}) as Record<string, unknown>,
    projectId: row.projectId,
    phaseId: row.phaseId,
    employeeId: row.employeeId,
    reportId: row.reportId,
    occurredAt: row.occurredAt.toISOString(),
    createdAt: row.createdAt.toISOString(),
    readAt: row.readAt ? row.readAt.toISOString() : null,
  };
}
