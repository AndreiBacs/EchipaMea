import type { Prisma } from '@prisma/client';
import { dateToDayKey } from '../common/util/day-key';
import { deriveFromPhases } from './project-status.service';
import type {
  PhaseWorkInstructionDto,
  ProjectDto,
  ProjectPhaseDto,
  WorkInstructionMediaDto,
} from './dto/project.dto';

/**
 * The canonical read shape for a project.
 *
 * Everything the API reports as a scalar but stores relationally -- assignments,
 * submissions, reviews, instruction media -- is loaded here so the mappers below
 * can derive it. Kept in one place so projects, phases and the worker-scoped
 * endpoints cannot drift into reporting different values for the same field.
 */
export const projectInclude = {
  assignments: { include: { employee: { select: { id: true, name: true } } } },
  phases: {
    where: { deletedAt: null },
    orderBy: { sortIndex: 'asc' },
    include: {
      assignments: { select: { employeeId: true } },
      submissions: {
        orderBy: { submittedAt: 'asc' },
        select: { employeeId: true, submittedAt: true },
      },
      reviews: {
        orderBy: { createdAt: 'desc' },
        take: 1,
        select: { approved: true, notes: true, reviewedById: true, createdAt: true },
      },
      workInstructions: {
        orderBy: { sortIndex: 'asc' },
        include: {
          media: {
            orderBy: { sortIndex: 'asc' },
            include: {
              media: { select: { id: true, contentType: true, byteSize: true, kind: true } },
            },
          },
        },
      },
    },
  },
} satisfies Prisma.ProjectInclude;

export type ProjectWithRelations = Prisma.ProjectGetPayload<{ include: typeof projectInclude }>;
type PhaseWithRelations = ProjectWithRelations['phases'][number];

export interface MapperOptions {
  /**
   * Base URL for media links, e.g. `https://api.host`. Media is served through
   * an authenticated endpoint rather than a raw storage path, because a storage
   * key means nothing to the client and must not be publicly guessable.
   */
  mediaBaseUrl: string;
}

export function toProjectDto(project: ProjectWithRelations, options: MapperOptions): ProjectDto {
  const phases = project.phases.map((phase) => toPhaseDto(phase, options));

  // Sorted by name so the derived list is stable across requests; the Flutter
  // UI renders it directly as a comma-joined label.
  const assignedEmployees = [...project.assignments]
    .map((a) => a.employee)
    .sort((a, b) => (a.name < b.name ? -1 : a.name > b.name ? 1 : 0));

  return {
    id: project.id,
    name: project.name,
    clientId: project.clientId,
    // Derived, never read from a column.
    status: project.closedAt ? 'done' : deriveFromPhases(project.phases),
    workers: assignedEmployees.map((e) => e.name),
    assignedEmployeeIds: assignedEmployees.map((e) => e.id),
    useClientAddress: project.useClientAddress,
    addressLine1: project.addressLine1,
    city: project.city,
    state: project.state,
    zipCode: project.zipCode,
    latitude: project.latitude,
    longitude: project.longitude,
    closedAt: project.closedAt ? project.closedAt.toISOString() : null,
    phases,
  };
}

export function toPhaseDto(phase: PhaseWithRelations, options: MapperOptions): ProjectPhaseDto {
  const latestReview = phase.reviews[0];

  // Submission order, de-duplicated: one worker submitting twice should appear
  // once, at the position of their first submission.
  const submittedByEmployeeIds = [...new Set(phase.submissions.map((s) => s.employeeId))];
  const lastSubmission = phase.submissions[phase.submissions.length - 1];

  return {
    id: phase.id,
    name: phase.name,
    // Read as UTC components: the column is a bare DATE and must not be shifted
    // into the server's local zone on the way out.
    startDate: dateToDayKey(phase.startDate),
    endDate: dateToDayKey(phase.endDate),
    description: phase.description,
    status: phase.status,
    assignedEmployeeIds: phase.assignments.map((a) => a.employeeId),
    submittedAt: lastSubmission ? lastSubmission.submittedAt.toISOString() : null,
    submittedByEmployeeIds,
    reviewedAt: latestReview ? latestReview.createdAt.toISOString() : null,
    reviewedByForemanId: latestReview ? latestReview.reviewedById : null,
    reviewNotes: latestReview ? latestReview.notes : null,
    workInstructions: phase.workInstructions.map((instruction) =>
      toWorkInstructionDto(instruction, options),
    ),
  };
}

type InstructionWithMedia = PhaseWithRelations['workInstructions'][number];

function toWorkInstructionDto(
  instruction: InstructionWithMedia,
  options: MapperOptions,
): PhaseWorkInstructionDto {
  const photos: WorkInstructionMediaDto[] = [];
  const audio: WorkInstructionMediaDto[] = [];

  for (const link of instruction.media) {
    const dto: WorkInstructionMediaDto = {
      id: link.media.id,
      url: `${options.mediaBaseUrl}/media/${link.media.id}/content`,
      contentType: link.media.contentType,
      byteSize: link.media.byteSize,
    };
    if (link.slot === 'instructionAudio') audio.push(dto);
    else photos.push(dto);
  }

  return { id: instruction.id, text: instruction.text, photos, audio };
}
