import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { z } from 'zod';
import { inlinePhaseSchema } from '../../projects/dto/project.dto';

/** Standalone creation reuses the inline shape so both paths cannot drift. */
export const phaseCreateSchema = inlinePhaseSchema;
export type PhaseCreateRequest = z.infer<typeof phaseCreateSchema>;

export const phaseUpdateSchema = inlinePhaseSchema
  .partial()
  .refine((value) => Object.keys(value).length > 0, {
    message: 'Provide at least one field to update.',
  });
export type PhaseUpdateRequest = z.infer<typeof phaseUpdateSchema>;

export const phaseReorderSchema = z.object({
  phaseIds: z
    .array(z.string().min(1))
    .min(1, 'Provide the full ordering.')
    .refine((ids) => new Set(ids).size === ids.length, {
      message: 'phaseIds must not contain duplicates.',
    }),
});
export type PhaseReorderRequest = z.infer<typeof phaseReorderSchema>;

/**
 * `employeeId` is optional: for a worker token the server takes the identity
 * from the JWT rather than trusting the body. It remains accepted so a foreman
 * can submit on a worker's behalf.
 */
export const phaseSubmitSchema = z.object({
  employeeId: z.string().trim().min(1).optional(),
});
export type PhaseSubmitRequest = z.infer<typeof phaseSubmitSchema>;

/** `foremanId` likewise comes from the JWT; the field is legacy compatibility. */
export const phaseReviewSchema = z.object({
  approved: z.boolean(),
  foremanId: z.string().trim().min(1).optional(),
  reviewNotes: z.string().max(5000).nullish(),
});
export type PhaseReviewRequest = z.infer<typeof phaseReviewSchema>;

export class PhaseReportSummaryDto {
  @ApiProperty() id!: string;
  @ApiProperty() employeeId!: string;
  @ApiProperty() employeeName!: string;
  @ApiProperty() description!: string;
  @ApiProperty({ format: 'date-time' }) submittedAt!: string;
  @ApiProperty() photoCount!: number;
  @ApiProperty() hasVoiceMemo!: boolean;
  @ApiPropertyOptional({ type: [String] }) photoUrls?: string[];
  @ApiPropertyOptional({ nullable: true }) voiceMemoUrl?: string | null;
}
