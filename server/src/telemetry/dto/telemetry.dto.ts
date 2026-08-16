import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { z } from 'zod';
import { isValidDayKey } from '../../common/util/day-key';

/**
 * A time window for reading telemetry.
 *
 * `from`/`to` are full instants rather than calendar days: unlike the daily
 * sequence, a location trail is a moment-in-time series and the foreman asks
 * questions like "where was the crew at 14:00". Absent bounds default to the
 * last 24 hours, which is what a foreman opening a map wants and also stops an
 * unbounded scan of the whole retention window.
 */
export const telemetryWindowSchema = z.object({
  employeeId: z.string().trim().min(1).optional(),
  from: z.coerce.date().optional(),
  to: z.coerce.date().optional(),
  limit: z.coerce.number().int().min(1).max(1000).default(500),
});
export type TelemetryWindowQuery = z.infer<typeof telemetryWindowSchema>;

export const arrivalListQuerySchema = z.object({
  projectId: z.string().trim().min(1).optional(),
  employeeId: z.string().trim().min(1).optional(),
  /** A bare calendar date, never timezone-converted -- same rule as sequences. */
  day: z.string().refine(isValidDayKey, 'Expected a calendar date as YYYY-MM-DD.').optional(),
  limit: z.coerce.number().int().min(1).max(500).default(200),
});
export type ArrivalListQuery = z.infer<typeof arrivalListQuerySchema>;

export class LocationSampleDto {
  @ApiProperty() employeeId!: string;
  @ApiProperty({ description: 'Name at the time of the fix, not the current one.' })
  employeeName!: string;
  @ApiProperty() latitude!: number;
  @ApiProperty() longitude!: number;
  @ApiProperty() accuracyMeters!: number;
  @ApiProperty({
    format: 'date-time',
    description: "The device's send-time wall clock, not the GPS fix time.",
  })
  capturedAt!: string;
  @ApiProperty({ format: 'date-time', description: 'When the server stored it.' })
  receivedAt!: string;
}

export class LocationTrailDto {
  @ApiProperty({ type: [LocationSampleDto] }) items!: LocationSampleDto[];
  @ApiProperty() page!: { limit: number; total: number };
  @ApiProperty({ format: 'date-time' }) from!: string;
  @ApiProperty({ format: 'date-time' }) to!: string;
}

export class LatestLocationDto {
  @ApiProperty() employeeId!: string;
  @ApiProperty() employeeName!: string;
  @ApiProperty() latitude!: number;
  @ApiProperty() longitude!: number;
  @ApiProperty() accuracyMeters!: number;
  @ApiProperty({
    format: 'date-time',
    description: "The device's own clock. Untrusted -- see clockSkewSeconds.",
  })
  capturedAt!: string;
  @ApiProperty({
    format: 'date-time',
    description:
      'Server-assigned. This is what "last seen" is ordered by, so a device with a wrong ' +
      'clock cannot pin itself to the top of the list.',
  })
  receivedAt!: string;
  @ApiProperty({
    description:
      'Seconds since the server received the fix. The app samples every 30 minutes and only ' +
      'inside working hours, so a large value is normal and does not mean the worker is missing.',
  })
  ageSeconds!: number;
  @ApiProperty({
    description:
      'capturedAt minus receivedAt. Near zero for a healthy device; a large magnitude means ' +
      "the phone's clock is wrong, which is worth surfacing rather than silently correcting.",
  })
  clockSkewSeconds!: number;
}

export class LatestLocationsDto {
  @ApiProperty({ type: [LatestLocationDto] }) items!: LatestLocationDto[];
}

export class ArrivalDto {
  @ApiProperty() id!: string;
  @ApiProperty() projectId!: string;
  @ApiPropertyOptional() projectName?: string;
  @ApiProperty() employeeId!: string;
  @ApiPropertyOptional() employeeName?: string;
  @ApiProperty({ format: 'date-time' }) arrivedAt!: string;
}

export class ArrivalsDto {
  @ApiProperty({ type: [ArrivalDto] }) items!: ArrivalDto[];
  @ApiProperty() page!: { limit: number; total: number };
}
