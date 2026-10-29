import { Controller, Get, HttpCode, HttpStatus, Param, Post, Query } from '@nestjs/common';
import { ApiOkResponse, ApiOperation, ApiParam, ApiQuery, ApiTags } from '@nestjs/swagger';
import { CurrentForeman } from '../common/decorators/current-principal.decorator';
import { zodBody } from '../common/pipes/zod-validation.pipe';
import type { ForemanPrincipal } from '../common/auth/principal';
import { NotificationsService } from './notifications.service';
import {
  MarkAllReadResultDto,
  NotificationDto,
  NotificationListQuery,
  PagedNotificationsDto,
  UnreadCountDto,
  notificationListQuerySchema,
} from './dto/notification.dto';

/**
 * Foreman-only by the guard's fail-closed default: notifications are addressed
 * to a `User`, and a worker token has no user to be addressed as.
 */
@ApiTags('Notifications')
@Controller('notifications')
export class NotificationsController {
  constructor(private readonly notifications: NotificationsService) {}

  @Get()
  @ApiOperation({
    operationId: 'listNotifications',
    summary: 'Notifications addressed to the signed-in foreman',
    description:
      'Newest first, cursor-paginated. Read state is per recipient: one foreman opening the ' +
      "app does not clear the badge on a colleague's phone. `unreadCount` in the response is " +
      'the total for this recipient, not the count within the page.',
  })
  @ApiQuery({ name: 'unreadOnly', required: false, type: Boolean })
  @ApiQuery({
    name: 'kind',
    required: false,
    enum: ['workerReportSubmitted', 'phaseApproved', 'phaseRejected', 'workerArrived'],
  })
  @ApiQuery({ name: 'limit', required: false, type: Number })
  @ApiQuery({ name: 'cursor', required: false })
  @ApiQuery({ name: 'withTotal', required: false, type: Boolean })
  @ApiOkResponse({ type: PagedNotificationsDto })
  list(
    @CurrentForeman() principal: ForemanPrincipal,
    @Query(zodBody(notificationListQuerySchema)) query: NotificationListQuery,
  ): Promise<PagedNotificationsDto> {
    return this.notifications.list(principal, query);
  }

  @Get('unread-count')
  @ApiOperation({
    operationId: 'getUnreadNotificationCount',
    summary: 'Unread count for the badge',
    description:
      'A cheap poll for clients that only need the number. The list endpoint already returns ' +
      'it, so this is for refreshing the badge without refetching the list.',
  })
  @ApiOkResponse({ type: UnreadCountDto })
  async unreadCount(@CurrentForeman() principal: ForemanPrincipal): Promise<UnreadCountDto> {
    return { unreadCount: await this.notifications.unreadCount(principal) };
  }

  @Post('read-all')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    operationId: 'markAllNotificationsRead',
    summary: 'Mark every notification read for this foreman',
    description: 'What the app-bar badge tap does today, except that it now survives a restart.',
  })
  @ApiOkResponse({ type: MarkAllReadResultDto })
  markAllRead(@CurrentForeman() principal: ForemanPrincipal): Promise<MarkAllReadResultDto> {
    return this.notifications.markAllRead(principal);
  }

  @Post(':notificationId/read')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    operationId: 'markNotificationRead',
    summary: 'Mark one notification read',
    description:
      'Idempotent: an already-read notification keeps its original `readAt` rather than being ' +
      'stamped again.',
  })
  @ApiParam({ name: 'notificationId' })
  @ApiOkResponse({ type: NotificationDto })
  markRead(
    @CurrentForeman() principal: ForemanPrincipal,
    @Param('notificationId') notificationId: string,
  ): Promise<NotificationDto> {
    return this.notifications.markRead(principal, notificationId);
  }

  @Post(':notificationId/unread')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    operationId: 'markNotificationUnread',
    summary: 'Mark one notification back to unread',
    description: 'For flagging something to come back to after opening it by accident.',
  })
  @ApiParam({ name: 'notificationId' })
  @ApiOkResponse({ type: NotificationDto })
  markUnread(
    @CurrentForeman() principal: ForemanPrincipal,
    @Param('notificationId') notificationId: string,
  ): Promise<NotificationDto> {
    return this.notifications.markUnread(principal, notificationId);
  }
}
