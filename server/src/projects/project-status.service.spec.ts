import type { PhaseStatus } from '@prisma/client';
import { ProjectStatusService, deriveFromPhases } from './project-status.service';

/**
 * The truth table below is transcribed from the Dart original. If these ever
 * disagree, the app and the server disagree about what "done" means, which the
 * user sees as a project silently changing state.
 */
const phases = (...statuses: PhaseStatus[]) => statuses.map((status) => ({ status }));

describe('deriveFromPhases', () => {
  it('treats a project with no phases as planned', () => {
    expect(deriveFromPhases([])).toBe('planned');
  });

  it('is planned while every phase is notStarted', () => {
    expect(deriveFromPhases(phases('notStarted'))).toBe('planned');
    expect(deriveFromPhases(phases('notStarted', 'notStarted'))).toBe('planned');
  });

  it('is done only when every phase is done', () => {
    expect(deriveFromPhases(phases('done'))).toBe('done');
    expect(deriveFromPhases(phases('done', 'done'))).toBe('done');
  });

  it('is inProgress when any phase has left notStarted', () => {
    expect(deriveFromPhases(phases('inProgress'))).toBe('inProgress');
    expect(deriveFromPhases(phases('notStarted', 'inProgress'))).toBe('inProgress');
    expect(deriveFromPhases(phases('pendingReview'))).toBe('inProgress');
    expect(deriveFromPhases(phases('notStarted', 'pendingReview'))).toBe('inProgress');
  });

  it('is inProgress when some but not all phases are done', () => {
    expect(deriveFromPhases(phases('done', 'notStarted'))).toBe('inProgress');
    expect(deriveFromPhases(phases('done', 'inProgress'))).toBe('inProgress');
  });

  it('matches the seeded demo projects', () => {
    // p1: Demolition inProgress + Finishing notStarted
    expect(deriveFromPhases(phases('inProgress', 'notStarted'))).toBe('inProgress');
    // p2: single Inspection phase, notStarted
    expect(deriveFromPhases(phases('notStarted'))).toBe('planned');
    // p3: single Install phase, done
    expect(deriveFromPhases(phases('done'))).toBe('done');
  });
});

describe('ProjectStatusService', () => {
  const service = new ProjectStatusService();

  it('honours the closedAt override regardless of phase state', () => {
    const closed = new Date('2026-08-14T00:00:00.000Z');
    expect(service.derive(closed, phases('notStarted'))).toBe('done');
    expect(service.derive(closed, [])).toBe('done');
    expect(service.derive(closed, phases('inProgress', 'notStarted'))).toBe('done');
  });

  it('falls back to phase derivation when not closed', () => {
    expect(service.derive(null, phases('inProgress'))).toBe('inProgress');
    expect(service.derive(undefined, phases('done'))).toBe('done');
  });

  it('does not treat a project as done merely because it has no phases', () => {
    expect(service.derive(null, [])).toBe('planned');
  });
});
