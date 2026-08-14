import { dayKeyToDate } from '../common/util/day-key';
import {
  reconcileManualOrder,
  suggestSequence,
  type SequenceCandidatePhase,
} from './sequence-derivation';

function phase(
  id: string,
  name: string,
  start: string,
  end: string,
  assignees: string[],
): SequenceCandidatePhase {
  return {
    id,
    name,
    startDate: dayKeyToDate(start),
    endDate: dayKeyToDate(end),
    assignedEmployeeIds: assignees,
  };
}

describe('suggestSequence', () => {
  const demolition = phase('p1_phase_1', 'Demolition', '2026-04-13', '2026-04-16', ['e1']);
  const finishing = phase('p1_phase_2', 'Finishing', '2026-04-17', '2026-04-24', ['e1']);
  const inspection = phase('p2_phase_1', 'Inspection', '2026-04-14', '2026-04-15', ['e3']);

  const all = [demolition, finishing, inspection];

  it('includes only phases assigned to the worker', () => {
    expect(suggestSequence(all, 'e1', dayKeyToDate('2026-04-14'))).toEqual(['p1_phase_1']);
    expect(suggestSequence(all, 'e3', dayKeyToDate('2026-04-14'))).toEqual(['p2_phase_1']);
  });

  it('returns nothing for a worker with no assignments that day', () => {
    expect(suggestSequence(all, 'e2', dayKeyToDate('2026-04-14'))).toEqual([]);
  });

  it('treats the date window as inclusive on both ends', () => {
    expect(suggestSequence(all, 'e1', dayKeyToDate('2026-04-13'))).toEqual(['p1_phase_1']);
    expect(suggestSequence(all, 'e1', dayKeyToDate('2026-04-16'))).toEqual(['p1_phase_1']);
    expect(suggestSequence(all, 'e1', dayKeyToDate('2026-04-12'))).toEqual([]);
    expect(suggestSequence(all, 'e1', dayKeyToDate('2026-04-17'))).toEqual(['p1_phase_2']);
  });

  it('orders by start date ascending', () => {
    const early = phase('late-name', 'Zzz', '2026-05-01', '2026-05-10', ['e1']);
    const late = phase('early-name', 'Aaa', '2026-05-02', '2026-05-10', ['e1']);
    expect(suggestSequence([late, early], 'e1', dayKeyToDate('2026-05-05'))).toEqual([
      'late-name',
      'early-name',
    ]);
  });

  it('breaks ties on name using code-unit order, matching Dart compareTo', () => {
    const b = phase('b', 'Bravo', '2026-05-01', '2026-05-10', ['e1']);
    const a = phase('a', 'Alpha', '2026-05-01', '2026-05-10', ['e1']);
    const upper = phase('u', 'ALPHA', '2026-05-01', '2026-05-10', ['e1']);
    // 'A' (65) sorts before 'B' (66); uppercase 'ALPHA' before 'Alpha'
    // because 'L' (76) < 'l' (108). localeCompare would disagree here.
    expect(suggestSequence([b, a, upper], 'e1', dayKeyToDate('2026-05-05'))).toEqual([
      'u',
      'a',
      'b',
    ]);
  });

  it('handles a phase assigned to several workers', () => {
    const shared = phase('shared', 'Shared', '2026-06-01', '2026-06-02', ['e1', 'e2']);
    expect(suggestSequence([shared], 'e1', dayKeyToDate('2026-06-01'))).toEqual(['shared']);
    expect(suggestSequence([shared], 'e2', dayKeyToDate('2026-06-01'))).toEqual(['shared']);
    expect(suggestSequence([shared], 'e3', dayKeyToDate('2026-06-01'))).toEqual([]);
  });
});

describe('reconcileManualOrder', () => {
  const known = new Set(['a', 'b', 'c']);

  it('keeps the stored order when everything still exists', () => {
    expect(reconcileManualOrder(['c', 'a', 'b'], ['a', 'b', 'c'], known)).toEqual(['c', 'a', 'b']);
  });

  it('drops ids that no longer exist', () => {
    expect(reconcileManualOrder(['c', 'gone', 'a'], ['a', 'c'], known)).toEqual(['c', 'a']);
  });

  it('appends newly qualifying phases rather than hiding them', () => {
    // 'b' became assigned after the override was saved.
    expect(reconcileManualOrder(['c', 'a'], ['a', 'b', 'c'], known)).toEqual(['c', 'a', 'b']);
  });

  it('de-duplicates a corrupted stored order', () => {
    expect(reconcileManualOrder(['a', 'a', 'b'], ['a', 'b'], known)).toEqual(['a', 'b']);
  });

  it('returns the suggestion when the override is empty', () => {
    expect(reconcileManualOrder([], ['a', 'b'], known)).toEqual(['a', 'b']);
  });
});
