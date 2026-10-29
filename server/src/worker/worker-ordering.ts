import { byCodeUnit } from '../common/util/sort';

/**
 * Ordering the worker's job list: in progress first, then planned, then done,
 * and by name within each group.
 *
 * A direct port of the sort in `worker_assigned_projects_provider.dart`. It
 * lives here rather than inline in a query because the status it sorts on is
 * derived from phases and cannot be an ORDER BY.
 */
const STATUS_RANK: Record<string, number> = { inProgress: 0, planned: 1, done: 2 };

export function compareWorkerProjects(
  a: { status: string; name: string },
  b: { status: string; name: string },
): number {
  // An unrecognised status sorts last rather than throwing: a new status value
  // should push a job to the bottom of the list, not break the whole screen.
  const byStatus = (STATUS_RANK[a.status] ?? 9) - (STATUS_RANK[b.status] ?? 9);
  return byStatus !== 0 ? byStatus : byCodeUnit(a.name, b.name);
}

export interface TimestampedSample {
  capturedAtDate: Date;
}

/**
 * Splits a location batch into what is new and what the server already has.
 *
 * `storedMillis` seeds the set, so a resent batch is recognised. Accepted
 * samples are added to it as they pass, which is what also catches duplicates
 * *within* a single batch -- a client whose outbox buffered the same fix twice
 * would otherwise write it twice, since there is no unique constraint to lean
 * on.
 */
export function selectFreshSamples<T extends TimestampedSample>(
  samples: T[],
  storedMillis: Iterable<number>,
): { fresh: T[]; duplicates: number } {
  const seen = new Set(storedMillis);
  const fresh: T[] = [];

  for (const sample of samples) {
    const key = sample.capturedAtDate.getTime();
    if (seen.has(key)) continue;
    seen.add(key);
    fresh.push(sample);
  }

  return { fresh, duplicates: samples.length - fresh.length };
}
