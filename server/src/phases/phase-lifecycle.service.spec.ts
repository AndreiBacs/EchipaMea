import type { PhaseStatus } from '@prisma/client';
import { AppException } from '../common/errors/app-exception';
import { PhaseLifecycleService, type PhaseAction } from './phase-lifecycle.service';

const strict = () =>
  new PhaseLifecycleService({ phaseTransitionsLenient: false } as never);
const lenient = () =>
  new PhaseLifecycleService({ phaseTransitionsLenient: true } as never);

describe('PhaseLifecycleService (strict)', () => {
  const service = strict();

  it.each<[PhaseStatus, PhaseAction, PhaseStatus]>([
    ['notStarted', 'start', 'inProgress'],
    ['notStarted', 'submit', 'pendingReview'],
    ['inProgress', 'submit', 'pendingReview'],
    ['pendingReview', 'approve', 'done'],
    ['pendingReview', 'reject', 'inProgress'],
    ['done', 'reopen', 'inProgress'],
  ])('allows %s --%s--> %s', (from, action, to) => {
    expect(service.next(from, action)).toBe(to);
  });

  it.each<[PhaseStatus, PhaseAction]>([
    ['done', 'submit'],
    ['done', 'approve'],
    ['notStarted', 'approve'],
    ['notStarted', 'reject'],
    ['inProgress', 'approve'],
    ['inProgress', 'start'],
    ['pendingReview', 'submit'],
    ['pendingReview', 'start'],
  ])('rejects %s --%s-->', (from, action) => {
    expect(() => service.next(from, action)).toThrow(AppException);
    try {
      service.next(from, action);
    } catch (error) {
      expect((error as AppException).code).toBe('PHASE_INVALID_TRANSITION');
      expect((error as AppException).getStatus()).toBe(409);
    }
  });

  it('rejecting review returns to inProgress, not notStarted', () => {
    // Matches the Flutter reviewPhase behaviour: the work was started, it was
    // just not accepted.
    expect(service.next('pendingReview', 'reject')).toBe('inProgress');
  });

  it('reports legality without throwing', () => {
    expect(service.canTransition('notStarted', 'start')).toBe(true);
    expect(service.canTransition('done', 'submit')).toBe(false);
  });
});

describe('PhaseLifecycleService (lenient migration mode)', () => {
  const service = lenient();

  it('permits transitions the strict machine rejects', () => {
    // The current client submits and reviews from any status; lenient mode
    // exists so enabling the backend does not break that mid-migration.
    expect(service.next('done', 'submit')).toBe('pendingReview');
    expect(service.next('notStarted', 'approve')).toBe('done');
  });

  it('still produces the correct target for legal transitions', () => {
    expect(service.next('pendingReview', 'reject')).toBe('inProgress');
    expect(service.next('notStarted', 'start')).toBe('inProgress');
  });
});
