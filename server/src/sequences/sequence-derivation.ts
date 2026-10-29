/**
 * Suggested daily work sequence.
 *
 * Port of `ProjectsNotifier.suggestedSequenceForDay` in the Flutter app: the
 * phases assigned to a worker whose date window covers the given day, ordered
 * by start date and then by name.
 *
 * Only *manual* overrides are stored. A suggestion is recomputed on every read,
 * so it automatically follows edits to phase dates or assignments instead of
 * going stale.
 */

import { byCodeUnit } from '../common/util/sort';

export interface SequenceCandidatePhase {
  id: string;
  name: string;
  startDate: Date;
  endDate: Date;
  assignedEmployeeIds: string[];
}

/** Inclusive on both ends, comparing calendar dates only. */
function covers(phase: SequenceCandidatePhase, day: Date): boolean {
  const d = day.getTime();
  return d >= phase.startDate.getTime() && d <= phase.endDate.getTime();
}

export function suggestSequence(
  phases: SequenceCandidatePhase[],
  employeeId: string,
  day: Date,
): string[] {
  return phases
    .filter((phase) => phase.assignedEmployeeIds.includes(employeeId) && covers(phase, day))
    .sort((a, b) => {
      const byStart = a.startDate.getTime() - b.startDate.getTime();
      if (byStart !== 0) return byStart;
      return byCodeUnit(a.name, b.name);
    })
    .map((phase) => phase.id);
}

/**
 * Reconciles a stored manual order against the phases that actually still
 * qualify.
 *
 * A saved order can drift: a phase may be deleted, unassigned, or have its
 * dates moved off the day. Ids that no longer exist are dropped, and phases the
 * override never mentioned are appended in suggested order rather than hidden --
 * silently omitting newly assigned work would lose a worker's job for that day.
 */
export function reconcileManualOrder(
  storedOrder: string[],
  suggested: string[],
  knownPhaseIds: ReadonlySet<string>,
): string[] {
  const seen = new Set<string>();
  const result: string[] = [];

  for (const id of storedOrder) {
    if (!knownPhaseIds.has(id) || seen.has(id)) continue;
    seen.add(id);
    result.push(id);
  }

  for (const id of suggested) {
    if (seen.has(id)) continue;
    seen.add(id);
    result.push(id);
  }

  return result;
}
