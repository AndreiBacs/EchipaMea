import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { z } from 'zod';
import { pageQuerySchema } from '../../common/dto/page.dto';

export const projectStatusEnum = z.enum(['planned', 'inProgress', 'done']);
export const phaseStatusEnum = z.enum(['notStarted', 'inProgress', 'pendingReview', 'done']);

/** Bare calendar date. Phases are date-only; the draft spec's date-time was wrong. */
export const dayString = z
  .string()
  .regex(/^\d{4}-\d{2}-\d{2}$/, 'Expected a calendar date as YYYY-MM-DD.');

/**
 * Phases may be sent inline when creating a project, which is how the app's
 * "draft phases then save" flow works. Unlike the draft spec, this uses the
 * *create* shape -- requiring `id` and `status` would have forced the client to
 * invent them.
 */
export const inlinePhaseSchema = z.object({
  id: z.string().optional(),
  name: z.string().trim().min(1, 'Phase name is required.').max(200),
  startDate: dayString,
  endDate: dayString,
  description: z.string().max(5000).default(''),
  assignedEmployeeIds: z.array(z.string()).default([]),
  workInstructions: z
    .array(
      z.object({
        id: z.string().optional(),
        text: z.string().max(5000).default(''),
        photoMediaIds: z.array(z.string()).default([]),
        audioMediaIds: z.array(z.string()).default([]),
      }),
    )
    .default([]),
});
export type InlinePhaseInput = z.infer<typeof inlinePhaseSchema>;

const projectBase = {
  name: z.string().trim().min(1, 'Project name is required.').max(200),
  clientId: z.string().min(1, 'A project must belong to a client.'),
  useClientAddress: z.boolean().default(true),
  addressLine1: z.string().trim().max(300).default(''),
  city: z.string().trim().max(120).default(''),
  state: z.string().trim().max(120).default(''),
  zipCode: z.string().trim().max(30).default(''),
  latitude: z.number().min(-90).max(90).nullish(),
  longitude: z.number().min(-180).max(180).nullish(),
};

/**
 * `status` and `workers` are accepted and ignored: the current client sends
 * them, and rejecting would break it before it is rewired. Both are derived.
 */
export const projectCreateSchema = z.object({
  ...projectBase,
  assignedEmployeeIds: z.array(z.string()).default([]),
  phases: z.array(inlinePhaseSchema).default([]),
  status: projectStatusEnum.optional(),
  workers: z.array(z.string()).optional(),
});
export type ProjectCreateRequest = z.infer<typeof projectCreateSchema>;

export const projectUpdateSchema = z
  .object({
    name: projectBase.name.optional(),
    clientId: projectBase.clientId.optional(),
    useClientAddress: z.boolean().optional(),
    addressLine1: z.string().trim().max(300).optional(),
    city: z.string().trim().max(120).optional(),
    state: z.string().trim().max(120).optional(),
    zipCode: z.string().trim().max(30).optional(),
    latitude: z.number().min(-90).max(90).nullish(),
    longitude: z.number().min(-180).max(180).nullish(),
    /**
     * Omitted means "leave untouched"; present means "replace the whole set".
     * Stated explicitly because it is the only rule that keeps the existing
     * form pages working -- they submit entire collections, not deltas.
     */
    assignedEmployeeIds: z.array(z.string()).optional(),
    status: projectStatusEnum.optional(),
    workers: z.array(z.string()).optional(),
  })
  .refine((value) => Object.keys(value).length > 0, {
    message: 'Provide at least one field to update.',
  });
export type ProjectUpdateRequest = z.infer<typeof projectUpdateSchema>;

export const projectListQuerySchema = pageQuerySchema.extend({
  q: z.string().trim().min(1).max(200).optional(),
  clientId: z.string().optional(),
  status: projectStatusEnum.optional(),
  assignedEmployeeId: z.string().optional(),
  include: z.enum(['phases']).optional(),
  sort: z.enum(['name', '-name', 'createdAt', '-createdAt']).default('name'),
});
export type ProjectListQuery = z.infer<typeof projectListQuerySchema>;

// --- Response shapes --------------------------------------------------------

export class WorkInstructionMediaDto {
  @ApiProperty() id!: string;
  @ApiProperty({ description: 'Fetch via GET /media/{id}/content or a signed URL.' })
  url!: string;
  @ApiProperty() contentType!: string;
  @ApiPropertyOptional() byteSize?: number;
}

export class PhaseWorkInstructionDto {
  @ApiProperty() id!: string;
  @ApiProperty() text!: string;
  @ApiProperty({ type: [WorkInstructionMediaDto] }) photos!: WorkInstructionMediaDto[];
  @ApiProperty({ type: [WorkInstructionMediaDto] }) audio!: WorkInstructionMediaDto[];
}

export class ProjectPhaseDto {
  @ApiProperty() id!: string;
  @ApiProperty() name!: string;
  @ApiProperty({ example: '2026-04-13', description: 'Calendar date, YYYY-MM-DD.' })
  startDate!: string;
  @ApiProperty({ example: '2026-04-16' }) endDate!: string;
  @ApiProperty() description!: string;
  @ApiProperty({ enum: ['notStarted', 'inProgress', 'pendingReview', 'done'] }) status!: string;
  @ApiProperty({ type: [String] }) assignedEmployeeIds!: string[];
  @ApiPropertyOptional({ format: 'date-time', nullable: true, readOnly: true })
  submittedAt?: string | null;
  @ApiProperty({ type: [String], readOnly: true }) submittedByEmployeeIds!: string[];
  @ApiPropertyOptional({ format: 'date-time', nullable: true, readOnly: true })
  reviewedAt?: string | null;
  @ApiPropertyOptional({ nullable: true, readOnly: true }) reviewedByForemanId?: string | null;
  @ApiPropertyOptional({ nullable: true, readOnly: true }) reviewNotes?: string | null;
  @ApiProperty({ type: [PhaseWorkInstructionDto] }) workInstructions!: PhaseWorkInstructionDto[];
}

export class ProjectDto {
  @ApiProperty() id!: string;
  @ApiProperty() name!: string;
  @ApiProperty() clientId!: string;
  @ApiProperty({
    enum: ['planned', 'inProgress', 'done'],
    readOnly: true,
    description:
      'Derived from the phases, or forced to `done` by POST /projects/{id}/done. Never stored.',
  })
  status!: string;
  @ApiProperty({
    type: [String],
    readOnly: true,
    description: 'Derived: names of the assigned employees. Send assignedEmployeeIds to change it.',
  })
  workers!: string[];
  @ApiProperty({ type: [String] }) assignedEmployeeIds!: string[];
  @ApiProperty() useClientAddress!: boolean;
  @ApiProperty() addressLine1!: string;
  @ApiProperty() city!: string;
  @ApiProperty() state!: string;
  @ApiProperty() zipCode!: string;
  @ApiPropertyOptional({ nullable: true }) latitude?: number | null;
  @ApiPropertyOptional({ nullable: true }) longitude?: number | null;
  @ApiPropertyOptional({ format: 'date-time', nullable: true, readOnly: true })
  closedAt?: string | null;
  @ApiProperty({ type: [ProjectPhaseDto] }) phases!: ProjectPhaseDto[];
}

export class PagedProjectsDto {
  @ApiProperty({ type: [ProjectDto] }) items!: ProjectDto[];
  @ApiProperty() page!: { limit: number; nextCursor?: string; total?: number };
}
