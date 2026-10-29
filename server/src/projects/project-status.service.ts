import { Injectable } from '@nestjs/common';
import type { PhaseStatus, ProjectStatus } from '@prisma/client';

/**
 * Project status is derived, never stored.
 *
 * This is a direct port of `projectStatusFromPhases` in
 * `lib/src/features/foreman/domain/entities/project.dart`. The Flutter app has
 * that function but writes `Project.status` directly in four places anyway
 * (addProject, updateProject, markProjectDone, submitPhaseForReview), which is
 * how a project can end up claiming `done` while a phase is still `notStarted`.
 * Here the derivation is the only source of truth.
 *
 * The one addition is `closedAt`: `POST /projects/{id}/done` is an explicit
 * foreman override, recorded as a timestamp rather than by mutating status.
 */
@Injectable()
export class ProjectStatusService {
  /**
   * @param closedAt manual "mark as done" override, if any
   * @param phases   non-deleted phases of the project
   */
  derive(closedAt: Date | null | undefined, phases: { status: PhaseStatus }[]): ProjectStatus {
    if (closedAt) return 'done';
    return deriveFromPhases(phases);
  }
}

/** Pure form, so it can be unit-tested and reused without the Nest container. */
export function deriveFromPhases(phases: { status: PhaseStatus }[]): ProjectStatus {
  if (phases.length === 0) return 'planned';

  const allDone = phases.every((p) => p.status === 'done');
  if (allDone) return 'done';

  const hasStarted = phases.some((p) => p.status !== 'notStarted');
  return hasStarted ? 'inProgress' : 'planned';
}
