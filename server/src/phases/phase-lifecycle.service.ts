import { Injectable } from '@nestjs/common';
import type { PhaseStatus } from '@prisma/client';
import { AppConfig } from '../common/config/configuration';
import { AppException } from '../common/errors/app-exception';
import { ErrorCode } from '../common/errors/error-codes';

export type PhaseAction = 'start' | 'submit' | 'approve' | 'reject' | 'reopen';

/**
 * The single place phase status may change.
 *
 *   notStarted                          --start-->  inProgress
 *   notStarted|inProgress|pendingReview --submit--> pendingReview
 *   pendingReview                       --approve-> done
 *   pendingReview                       --reject--> inProgress
 *   done                                --reopen--> inProgress
 *
 * Submitting from pendingReview is idempotent, not an error: phases span days
 * and workers report daily, so a second report before review is expected.
 *
 * Rejection returns to `inProgress` rather than `notStarted`, matching the
 * Flutter `reviewPhase` behaviour: the work was started, it just was not
 * accepted.
 *
 * The current client permits submit and review from *any* status. Enforcing the
 * machine is therefore a behaviour change, which is why
 * `PHASE_TRANSITIONS_LENIENT` exists as an escape hatch for the migration
 * window -- it logs and allows instead of rejecting.
 */
@Injectable()
export class PhaseLifecycleService {
  constructor(private readonly config: AppConfig) {}

  next(current: PhaseStatus, action: PhaseAction): PhaseStatus {
    const target = TRANSITIONS[current]?.[action];

    if (target) return target;

    if (this.config.phaseTransitionsLenient) {
      // Lenient mode still has to produce a sane target rather than leaving the
      // phase where it was, or a submit from `done` would silently do nothing.
      return FALLBACK[action];
    }

    throw AppException.conflict(
      `Cannot ${action} a phase that is ${current}.`,
      ErrorCode.PHASE_INVALID_TRANSITION,
      'status',
    );
  }

  /** True when the action is legal without attempting it. */
  canTransition(current: PhaseStatus, action: PhaseAction): boolean {
    return TRANSITIONS[current]?.[action] !== undefined;
  }
}

const TRANSITIONS: Record<PhaseStatus, Partial<Record<PhaseAction, PhaseStatus>>> = {
  notStarted: {
    start: 'inProgress',
    submit: 'pendingReview',
  },
  inProgress: {
    submit: 'pendingReview',
  },
  pendingReview: {
    approve: 'done',
    reject: 'inProgress',
    // Submitting again is a no-op rather than an error. A phase spans several
    // days and workers report at the end of each one, so a second report before
    // the foreman reviews the first is normal -- rejecting it would block a
    // worker from filing their day's work.
    submit: 'pendingReview',
  },
  done: {
    reopen: 'inProgress',
  },
};

const FALLBACK: Record<PhaseAction, PhaseStatus> = {
  start: 'inProgress',
  submit: 'pendingReview',
  approve: 'done',
  reject: 'inProgress',
  reopen: 'inProgress',
};
