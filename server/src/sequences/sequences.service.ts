import { Injectable } from '@nestjs/common';
import type { Prisma } from '@prisma/client';
import { AppException } from '../common/errors/app-exception';
import { ErrorCode } from '../common/errors/error-codes';
import { PrismaService } from '../common/prisma/prisma.service';
import { dateToDayKey, dayKeyToDate } from '../common/util/day-key';
import {
  reconcileManualOrder,
  suggestSequence,
  type SequenceCandidatePhase,
} from './sequence-derivation';
import type { DailyWorkerSequenceDto, DaySequencesDto } from './dto/sequence.dto';

/** Phase rows needed to compute a suggestion. */
const candidateSelect = {
  id: true,
  name: true,
  projectId: true,
  startDate: true,
  endDate: true,
  assignments: { select: { employeeId: true } },
} satisfies Prisma.ProjectPhaseSelect;

type CandidateRow = Prisma.ProjectPhaseGetPayload<{ select: typeof candidateSelect }>;

@Injectable()
export class SequencesService {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * The effective sequence for one worker on one project for one day.
   *
   * Never 404s for a missing override -- it falls back to the computed
   * suggestion with `isManual: false`. The draft spec documented a 404 here
   * while its own DELETE description promised a "fallback to suggested", which
   * was self-contradictory. 404 now means only that the project or worker does
   * not exist.
   */
  async getOne(
    companyId: string,
    projectId: string,
    workerId: string,
    dayKey: string,
  ): Promise<DailyWorkerSequenceDto> {
    await this.assertProjectExists(companyId, projectId);
    await this.assertEmployeeExists(companyId, workerId);

    const day = dayKeyToDate(dayKey);
    const phases = await this.loadCandidates(companyId, { projectId });
    const override = await this.prisma.dailySequenceOverride.findFirst({
      where: { companyId, projectId, employeeId: workerId, day },
    });

    return this.buildDto({
      projectId,
      workerId,
      dayKey,
      day,
      phases,
      storedOrder: override?.orderedPhaseIds,
    });
  }

  /**
   * Every sequence in the company for one day.
   *
   * This exists because the foreman dashboard renders a row per employee per
   * project inside a lazy list. Fetching that per key would issue a burst of
   * requests on the app's primary screen; one bulk read replaces all of them.
   */
  async getDay(companyId: string, dayKey: string): Promise<DaySequencesDto> {
    const day = dayKeyToDate(dayKey);
    const phases = await this.loadCandidates(companyId, {});
    const overrides = await this.prisma.dailySequenceOverride.findMany({
      where: { companyId, day },
    });

    const overrideByKey = new Map(
      overrides.map((o) => [`${o.projectId}|${o.employeeId}`, o.orderedPhaseIds]),
    );

    // Only (project, worker) pairs with something to do that day, plus any pair
    // carrying a manual override -- a foreman may have ordered phases whose date
    // windows have since moved, and silently dropping that would lose their edit.
    const pairs = new Set<string>();
    for (const phase of phases) {
      for (const assignment of phase.assignments) {
        pairs.add(`${phase.projectId}|${assignment.employeeId}`);
      }
    }
    for (const key of overrideByKey.keys()) pairs.add(key);

    const sequences: DailyWorkerSequenceDto[] = [];
    for (const key of pairs) {
      const [projectId, workerId] = key.split('|');
      if (!projectId || !workerId) continue;
      const dto = this.buildDto({
        projectId,
        workerId,
        dayKey,
        day,
        phases: phases.filter((p) => p.projectId === projectId),
        storedOrder: overrideByKey.get(key),
      });
      // A pair whose override reconciled to nothing has no work left that day.
      if (dto.orderedPhaseIds.length > 0) sequences.push(dto);
    }

    sequences.sort(
      (a, b) => a.workerId.localeCompare(b.workerId) || a.projectId.localeCompare(b.projectId),
    );

    const phaseNames: Record<string, string> = {};
    for (const phase of phases) phaseNames[phase.id] = phase.name;

    return { dayKey, sequences, phaseNames };
  }

  /** All of one worker's sequences for a day, across every project. */
  async getForWorker(
    companyId: string,
    workerId: string,
    dayKey: string,
  ): Promise<DaySequencesDto> {
    await this.assertEmployeeExists(companyId, workerId);
    const all = await this.getDay(companyId, dayKey);
    return {
      dayKey,
      sequences: all.sequences.filter((s) => s.workerId === workerId),
      phaseNames: all.phaseNames,
    };
  }

  /**
   * Saves a manual order.
   *
   * The ids must belong to the project, but they are deliberately not required
   * to match the suggestion: a foreman may legitimately schedule a phase whose
   * date window does not cover the day.
   */
  async save(
    companyId: string,
    projectId: string,
    workerId: string,
    dayKey: string,
    orderedPhaseIds: string[],
    createdById?: string,
  ): Promise<DailyWorkerSequenceDto> {
    await this.assertProjectExists(companyId, projectId);
    await this.assertEmployeeExists(companyId, workerId);

    const day = dayKeyToDate(dayKey);
    const phases = await this.loadCandidates(companyId, { projectId });
    const known = new Set(phases.map((p) => p.id));
    const foreign = orderedPhaseIds.filter((id) => !known.has(id));
    if (foreign.length > 0) {
      throw AppException.conflict(
        `These phases do not belong to project ${projectId}: ${foreign.join(', ')}.`,
        ErrorCode.SEQUENCE_PHASE_MISMATCH,
        'orderedPhaseIds',
      );
    }

    await this.prisma.dailySequenceOverride.upsert({
      where: { projectId_employeeId_day: { projectId, employeeId: workerId, day } },
      create: {
        companyId,
        projectId,
        employeeId: workerId,
        day,
        orderedPhaseIds,
        createdById: createdById ?? null,
      },
      update: { orderedPhaseIds },
    });

    return this.buildDto({
      projectId,
      workerId,
      dayKey,
      day,
      phases,
      storedOrder: orderedPhaseIds,
    });
  }

  /** Drops the override so reads fall back to the suggestion. Idempotent. */
  async reset(
    companyId: string,
    projectId: string,
    workerId: string,
    dayKey: string,
  ): Promise<void> {
    await this.assertProjectExists(companyId, projectId);
    await this.prisma.dailySequenceOverride.deleteMany({
      where: { companyId, projectId, employeeId: workerId, day: dayKeyToDate(dayKey) },
    });
  }

  // --- helpers -------------------------------------------------------------

  private buildDto(input: {
    projectId: string;
    workerId: string;
    dayKey: string;
    day: Date;
    phases: CandidateRow[];
    storedOrder?: string[];
  }): DailyWorkerSequenceDto {
    const candidates: SequenceCandidatePhase[] = input.phases.map((phase) => ({
      id: phase.id,
      name: phase.name,
      startDate: phase.startDate,
      endDate: phase.endDate,
      assignedEmployeeIds: phase.assignments.map((a) => a.employeeId),
    }));

    const suggestedPhaseIds = suggestSequence(candidates, input.workerId, input.day);

    const isManual = input.storedOrder !== undefined;
    const orderedPhaseIds = isManual
      ? reconcileManualOrder(
          input.storedOrder ?? [],
          suggestedPhaseIds,
          new Set(candidates.map((c) => c.id)),
        )
      : suggestedPhaseIds;

    return {
      projectId: input.projectId,
      dayKey: input.dayKey,
      workerId: input.workerId,
      orderedPhaseIds,
      suggestedPhaseIds,
      isManual,
    };
  }

  private loadCandidates(
    companyId: string,
    filter: { projectId?: string },
  ): Promise<CandidateRow[]> {
    return this.prisma.projectPhase.findMany({
      where: {
        companyId,
        deletedAt: null,
        ...(filter.projectId ? { projectId: filter.projectId } : {}),
        project: { deletedAt: null },
      },
      select: candidateSelect,
    });
  }

  private async assertProjectExists(companyId: string, projectId: string): Promise<void> {
    const found = await this.prisma.project.count({
      where: { id: projectId, companyId, deletedAt: null },
    });
    if (found === 0) throw AppException.notFound('Project', projectId);
  }

  private async assertEmployeeExists(companyId: string, employeeId: string): Promise<void> {
    const found = await this.prisma.employee.count({
      where: { id: employeeId, companyId, deletedAt: null },
    });
    if (found === 0) throw AppException.notFound('Employee', employeeId);
  }
}

/** Re-exported for callers that already hold a Date. */
export { dateToDayKey };
