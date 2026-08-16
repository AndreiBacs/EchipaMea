import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { z } from 'zod';
import {
  accuracyMetersSchema,
  clientTimestampSchema,
  latitudeSchema,
  longitudeSchema,
} from '../../common/dto/geo';
import { ProjectDto } from '../../projects/dto/project.dto';

/**
 * A worker's own profile.
 *
 * Deliberately not the full `EmployeeDto` list: a worker asks for itself and
 * gets itself. The working-hours fields are here because
 * `worker_telemetry_coordinator.dart` needs them to decide whether to open the
 * telemetry socket at all -- today it reads them out of `teamProvider`, the
 * *foreman's* roster of the entire company, which a worker should never hold.
 */
export class WorkerProfileDto {
  @ApiProperty() employeeId!: string;
  @ApiProperty() name!: string;
  @ApiProperty() role!: string;
  @ApiProperty() email!: string;
  @ApiProperty() phone!: string;
  @ApiProperty({ minimum: 0, maximum: 23 }) workStartHour!: number;
  @ApiProperty({ minimum: 0, maximum: 23 }) workEndHour!: number;
  @ApiProperty({
    type: [Number],
    description: 'ISO-8601 weekdays, 1=Mon .. 7=Sun. Gates location telemetry.',
  })
  workingDays!: number[];
  @ApiPropertyOptional({ nullable: true }) latitude?: number | null;
  @ApiPropertyOptional({ nullable: true }) longitude?: number | null;
  @ApiProperty() companyId!: string;
  @ApiProperty() companyName!: string;
}

export const workerProjectsQuerySchema = z.object({
  /**
   * Finished jobs are hidden by default, matching
   * `worker_assigned_projects_provider.dart`, which drops `ProjectStatus.done`.
   */
  includeDone: z
    .enum(['true', 'false'])
    .optional()
    .transform((v) => v === 'true'),
  limit: z.coerce.number().int().min(1).max(200).default(100),
});
export type WorkerProjectsQuery = z.infer<typeof workerProjectsQuerySchema>;

export class WorkerProjectsDto {
  @ApiProperty({ type: [ProjectDto] }) items!: ProjectDto[];
  @ApiProperty() page!: { limit: number; total: number };
}

export const arrivalCreateSchema = z.object({
  projectId: z.string().trim().min(1, 'projectId is required.'),
  /** Defaults to now. A phone that was briefly offline can backdate its tap. */
  arrivedAt: clientTimestampSchema.optional(),
});
export type ArrivalCreateRequest = z.infer<typeof arrivalCreateSchema>;

export class WorkerArrivalDto {
  @ApiProperty() id!: string;
  @ApiProperty() projectId!: string;
  @ApiProperty() employeeId!: string;
  @ApiProperty({ format: 'date-time' }) arrivedAt!: string;
  @ApiProperty({
    description: 'True when this matched a recent arrival instead of recording a new one.',
  })
  duplicate!: boolean;
}

export const locationSampleSchema = z.object({
  latitude: latitudeSchema,
  longitude: longitudeSchema,
  accuracyMeters: accuracyMetersSchema.default(0),
  capturedAt: clientTimestampSchema,
});

/**
 * The offline outbox flush.
 *
 * The telemetry socket only exists while the app is running and connected; the
 * plan has the client buffering roughly 200 samples (about four days at the
 * 30-minute interval) and posting them on reconnect. The cap is above that with
 * room to spare, and oversized batches are rejected rather than truncated --
 * silently dropping the tail would leave the client believing it had flushed.
 */
export const locationBatchSchema = z.object({
  samples: z
    .array(locationSampleSchema)
    .min(1, 'Send at least one sample.')
    .max(500, 'Send at most 500 samples per batch.'),
});
export type LocationBatchRequest = z.infer<typeof locationBatchSchema>;

export class LocationBatchResultDto {
  @ApiProperty({ description: 'Samples written.' }) accepted!: number;
  @ApiProperty({
    description:
      'Samples skipped as already stored. The client may resend a batch it never saw ' +
      'acknowledged, so this is expected rather than an error.',
  })
  duplicates!: number;
}
