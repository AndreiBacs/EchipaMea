import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { z } from 'zod';
import { isValidDayKey } from '../../common/util/day-key';

export const dayQuerySchema = z.object({
  day: z
    .string()
    .refine(isValidDayKey, 'Expected a calendar date as YYYY-MM-DD.')
    .describe(
      'Bare calendar date. Never timezone-converted: the client derives it from the worker ' +
        'local wall clock, so reinterpreting it would shift a whole day of work.',
    ),
});
export type DayQuery = z.infer<typeof dayQuerySchema>;

export const saveSequenceSchema = z.object({
  orderedPhaseIds: z.array(z.string().min(1)).refine((ids) => new Set(ids).size === ids.length, {
    message: 'orderedPhaseIds must not contain duplicates.',
  }),
});
export type SaveSequenceRequest = z.infer<typeof saveSequenceSchema>;

export class DailyWorkerSequenceDto {
  @ApiProperty() projectId!: string;
  @ApiProperty({ example: '2026-04-14' }) dayKey!: string;
  @ApiProperty() workerId!: string;

  @ApiProperty({
    type: [String],
    description: 'The effective order: the manual override when one exists, else the suggestion.',
  })
  orderedPhaseIds!: string[];

  @ApiProperty({
    type: [String],
    description:
      'What the server would suggest for this day, always present. Returned alongside the ' +
      'effective order so the planner can show "n suggested" without a second request.',
  })
  suggestedPhaseIds!: string[];

  @ApiProperty({ description: 'True when a foreman has saved an explicit order for this day.' })
  isManual!: boolean;
}

export class DaySequencesDto {
  @ApiProperty({ example: '2026-04-14' }) dayKey!: string;
  @ApiProperty({ type: [DailyWorkerSequenceDto] }) sequences!: DailyWorkerSequenceDto[];
  @ApiPropertyOptional({
    description: 'Phase id -> phase name, so callers can render without refetching projects.',
  })
  phaseNames?: Record<string, string>;
}
