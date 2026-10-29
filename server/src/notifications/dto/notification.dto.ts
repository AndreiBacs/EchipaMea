import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { z } from 'zod';
import { pageQuerySchema } from '../../common/dto/page.dto';

export const notificationKindEnum = z.enum([
  'workerReportSubmitted',
  'phaseApproved',
  'phaseRejected',
  'workerArrived',
]);

export const notificationListQuerySchema = pageQuerySchema.extend({
  unreadOnly: z
    .enum(['true', 'false'])
    .optional()
    .transform((v) => v === 'true'),
  kind: notificationKindEnum.optional(),
});
export type NotificationListQuery = z.infer<typeof notificationListQuerySchema>;

/**
 * One notification, as structured data.
 *
 * There is deliberately no `title` or `subtitle`. The app renders those from
 * `kind` and `payload` through `AppLocalizations`, in ro/hu/en -- a
 * server-rendered sentence would arrive in one language and stay in it. The
 * current client has this bug in miniature: `_onMessage` resolves the locale at
 * the moment a socket frame arrives, so switching language leaves the existing
 * notification list untranslated.
 */
export class NotificationDto {
  @ApiProperty() id!: string;
  @ApiProperty({
    enum: ['workerReportSubmitted', 'phaseApproved', 'phaseRejected', 'workerArrived'],
  })
  kind!: string;
  @ApiProperty({
    type: 'object',
    additionalProperties: true,
    description:
      'Kind-specific fields: projectName, phaseName, employeeName, photoCount, hasVoiceMemo. ' +
      'Snapshots taken when the event happened, so a later rename does not rewrite history.',
  })
  payload!: Record<string, unknown>;
  @ApiPropertyOptional({ nullable: true }) projectId?: string | null;
  @ApiPropertyOptional({ nullable: true }) phaseId?: string | null;
  @ApiPropertyOptional({ nullable: true }) employeeId?: string | null;
  @ApiPropertyOptional({ nullable: true }) reportId?: string | null;
  @ApiProperty({ format: 'date-time', description: 'When the event happened.' })
  occurredAt!: string;
  @ApiProperty({ format: 'date-time', description: 'When this row was created.' })
  createdAt!: string;
  @ApiPropertyOptional({ nullable: true, format: 'date-time' }) readAt?: string | null;
}

export class PagedNotificationsDto {
  @ApiProperty({ type: [NotificationDto] }) items!: NotificationDto[];
  @ApiProperty() page!: { limit: number; nextCursor?: string; total?: number };
  @ApiProperty({
    description:
      'Unread count for this recipient across all notifications, not just this page. ' +
      'Included here so the badge does not need a second request on every app start.',
  })
  unreadCount!: number;
}

export class UnreadCountDto {
  @ApiProperty() unreadCount!: number;
}

export class MarkAllReadResultDto {
  @ApiProperty({ description: 'Rows this call changed. Zero when nothing was unread.' })
  updated!: number;
  @ApiProperty({
    description: 'Always 0; returned so the client can set state without refetching.',
  })
  unreadCount!: number;
}
