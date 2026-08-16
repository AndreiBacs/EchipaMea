import { Injectable } from '@nestjs/common';
import type { Prisma } from '@prisma/client';
import { AppConfig } from '../common/config/configuration';
import { AppException } from '../common/errors/app-exception';
import { PrismaService } from '../common/prisma/prisma.service';
import { dayKeyToDate } from '../common/util/day-key';
import { MediaService } from '../media/media.service';
import type { ForemanPrincipal, Principal } from '../common/auth/principal';
import { projectInclude, toPhaseDto, toProjectDto } from '../projects/project.mapper';
import { ProjectsService } from '../projects/projects.service';
import type { ProjectDto, ProjectPhaseDto } from '../projects/dto/project.dto';
import { PhaseLifecycleService } from './phase-lifecycle.service';
import type {
  PhaseCreateRequest,
  PhaseReportSummaryDto,
  PhaseReviewRequest,
  PhaseUpdateRequest,
} from './dto/phase.dto';

@Injectable()
export class PhasesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly projects: ProjectsService,
    private readonly lifecycle: PhaseLifecycleService,
    private readonly media: MediaService,
    private readonly config: AppConfig,
  ) {}

  private get mapperOptions() {
    return { mediaBaseUrl: this.config.storagePublicBaseUrl };
  }

  async list(companyId: string, projectId: string): Promise<ProjectPhaseDto[]> {
    const project = await this.projects.findOrThrow(companyId, projectId);
    return project.phases.map((phase) => toPhaseDto(phase, this.mapperOptions));
  }

  async getById(
    companyId: string,
    projectId: string,
    phaseId: string,
  ): Promise<ProjectPhaseDto> {
    const project = await this.projects.findOrThrow(companyId, projectId);
    const phase = project.phases.find((p) => p.id === phaseId);
    if (!phase) throw AppException.notFound('Phase', phaseId);
    return toPhaseDto(phase, this.mapperOptions);
  }

  async create(
    companyId: string,
    projectId: string,
    input: PhaseCreateRequest,
  ): Promise<ProjectPhaseDto> {
    await this.projects.findOrThrow(companyId, projectId);
    await this.assertEmployeesExist(companyId, input.assignedEmployeeIds);
    await this.media.assertOwned(
      companyId,
      input.workInstructions.flatMap((i) => [...i.photoMediaIds, ...i.audioMediaIds]),
    );

    const phaseId = await this.prisma.$transaction(async (tx) => {
      // Appended at the end; `sortIndex` is dense so the next index is the count.
      const existing = await tx.projectPhase.count({
        where: { companyId, projectId, deletedAt: null },
      });
      return this.projects.createPhase(tx, companyId, projectId, input, existing);
    });

    return this.getById(companyId, projectId, phaseId);
  }

  async update(
    companyId: string,
    projectId: string,
    phaseId: string,
    input: PhaseUpdateRequest,
  ): Promise<ProjectPhaseDto> {
    const existing = await this.findPhaseOrThrow(companyId, projectId, phaseId);
    if (input.assignedEmployeeIds) {
      await this.assertEmployeesExist(companyId, input.assignedEmployeeIds);
    }
    if (input.workInstructions) {
      // Checked before the transaction: a media id from another tenant would
      // otherwise satisfy the foreign key and leak that file into this company.
      await this.media.assertOwned(
        companyId,
        input.workInstructions.flatMap((i) => [...i.photoMediaIds, ...i.audioMediaIds]),
      );
    }

    const startDate = input.startDate ? dayKeyToDate(input.startDate) : existing.startDate;
    const endDate = input.endDate ? dayKeyToDate(input.endDate) : existing.endDate;
    if (endDate.getTime() < startDate.getTime()) {
      throw AppException.badRequest('Phase end date cannot precede its start date.', 'endDate');
    }

    await this.prisma.$transaction(async (tx) => {
      await tx.projectPhase.update({
        where: { id_companyId: { id: phaseId, companyId } },
        data: {
          ...(input.name !== undefined ? { name: input.name } : {}),
          ...(input.startDate !== undefined ? { startDate } : {}),
          ...(input.endDate !== undefined ? { endDate } : {}),
          ...(input.description !== undefined ? { description: input.description } : {}),
        },
      });

      if (input.assignedEmployeeIds !== undefined) {
        await tx.phaseAssignment.deleteMany({ where: { phaseId } });
        const unique = [...new Set(input.assignedEmployeeIds)].filter((id) => id.length > 0);
        if (unique.length > 0) {
          await tx.phaseAssignment.createMany({
            data: unique.map((employeeId) => ({ phaseId, employeeId, companyId, projectId })),
            skipDuplicates: true,
          });
        }
      }

      // Work instructions are replaced wholesale when present. The Flutter
      // editor submits the entire list via `forPersistence()`, never a delta.
      if (input.workInstructions !== undefined) {
        await tx.phaseWorkInstruction.deleteMany({ where: { companyId, phaseId } });
        for (const [index, instruction] of input.workInstructions.entries()) {
          const created = await tx.phaseWorkInstruction.create({
            data: { companyId, phaseId, text: instruction.text, sortIndex: index },
          });
          const links = [
            ...instruction.photoMediaIds.map((mediaId, i) => ({
              mediaId,
              slot: 'instructionPhoto' as const,
              sortIndex: i,
            })),
            ...instruction.audioMediaIds.map((mediaId, i) => ({
              mediaId,
              slot: 'instructionAudio' as const,
              sortIndex: i,
            })),
          ];
          if (links.length > 0) {
            await tx.workInstructionMedia.createMany({
              data: links.map((l) => ({ ...l, instructionId: created.id, companyId })),
              skipDuplicates: true,
            });
          }
        }
      }
    });

    return this.getById(companyId, projectId, phaseId);
  }

  /**
   * Soft-deletes a phase and prunes it from any manual day orders.
   *
   * Mirrors `removePhase` in the Flutter controller, which also cleaned its
   * sequence map -- a stored order referencing a deleted phase would otherwise
   * resurface as a gap in the worker's day.
   */
  async remove(companyId: string, projectId: string, phaseId: string): Promise<void> {
    await this.findPhaseOrThrow(companyId, projectId, phaseId);

    await this.prisma.$transaction(async (tx) => {
      await tx.projectPhase.update({
        where: { id_companyId: { id: phaseId, companyId } },
        data: { deletedAt: new Date() },
      });

      const overrides = await tx.dailySequenceOverride.findMany({
        where: { companyId, projectId, orderedPhaseIds: { has: phaseId } },
      });
      for (const override of overrides) {
        const remaining = override.orderedPhaseIds.filter((id) => id !== phaseId);
        if (remaining.length === 0) {
          await tx.dailySequenceOverride.delete({
            where: {
              projectId_employeeId_day: {
                projectId: override.projectId,
                employeeId: override.employeeId,
                day: override.day,
              },
            },
          });
        } else {
          await tx.dailySequenceOverride.update({
            where: {
              projectId_employeeId_day: {
                projectId: override.projectId,
                employeeId: override.employeeId,
                day: override.day,
              },
            },
            data: { orderedPhaseIds: remaining },
          });
        }
      }

      // Keep sortIndex dense so "append at the end" stays correct.
      const survivors = await tx.projectPhase.findMany({
        where: { companyId, projectId, deletedAt: null },
        orderBy: { sortIndex: 'asc' },
        select: { id: true },
      });
      for (const [index, phase] of survivors.entries()) {
        await tx.projectPhase.update({
          where: { id_companyId: { id: phase.id, companyId } },
          data: { sortIndex: index },
        });
      }
    });
  }

  /** Full permutation reorder; partial lists are rejected. */
  async reorder(
    companyId: string,
    projectId: string,
    phaseIds: string[],
  ): Promise<ProjectPhaseDto[]> {
    const project = await this.projects.findOrThrow(companyId, projectId);
    const known = project.phases.map((p) => p.id);

    const missing = known.filter((id) => !phaseIds.includes(id));
    const unknown = phaseIds.filter((id) => !known.includes(id));
    if (missing.length > 0 || unknown.length > 0) {
      throw AppException.badRequest(
        'phaseIds must list every phase of the project exactly once.' +
          (missing.length ? ` Missing: ${missing.join(', ')}.` : '') +
          (unknown.length ? ` Unknown: ${unknown.join(', ')}.` : ''),
        'phaseIds',
      );
    }

    await this.prisma.$transaction(
      phaseIds.map((id, index) =>
        this.prisma.projectPhase.update({
          where: { id_companyId: { id, companyId } },
          data: { sortIndex: index },
        }),
      ),
    );

    return this.list(companyId, projectId);
  }

  // --- lifecycle -----------------------------------------------------------

  async start(companyId: string, projectId: string, phaseId: string): Promise<ProjectPhaseDto> {
    const phase = await this.findPhaseOrThrow(companyId, projectId, phaseId);
    const next = this.lifecycle.next(phase.status, 'start');
    await this.prisma.projectPhase.update({
      where: { id_companyId: { id: phaseId, companyId } },
      data: { status: next },
    });
    return this.getById(companyId, projectId, phaseId);
  }

  /**
   * Records a submission and moves the phase to pendingReview.
   *
   * The submitting employee is taken from a worker JWT rather than the body:
   * the previous flow trusted whatever `employeeId` the device claimed.
   */
  async submit(
    companyId: string,
    projectId: string,
    phaseId: string,
    principal: Principal,
    bodyEmployeeId: string | undefined,
    submittedAt = new Date(),
    reportId?: string,
  ): Promise<ProjectPhaseDto> {
    const phase = await this.findPhaseOrThrow(companyId, projectId, phaseId);

    const employeeId =
      principal.kind === 'employee' ? principal.employeeId : (bodyEmployeeId ?? '').trim();
    if (!employeeId) {
      throw AppException.badRequest(
        'employeeId is required when submitting with a foreman token.',
        'employeeId',
      );
    }
    await this.assertEmployeesExist(companyId, [employeeId]);

    const next = this.lifecycle.next(phase.status, 'submit');

    await this.prisma.$transaction([
      this.prisma.phaseSubmission.create({
        data: {
          companyId,
          phaseId,
          employeeId,
          submittedAt,
          ...(reportId ? { reportId } : {}),
        },
      }),
      this.prisma.projectPhase.update({
        where: { id_companyId: { id: phaseId, companyId } },
        data: { status: next },
      }),
    ]);

    return this.getById(companyId, projectId, phaseId);
  }

  async review(
    companyId: string,
    projectId: string,
    phaseId: string,
    principal: ForemanPrincipal,
    input: PhaseReviewRequest,
  ): Promise<ProjectDto> {
    const phase = await this.findPhaseOrThrow(companyId, projectId, phaseId);
    const next = this.lifecycle.next(phase.status, input.approved ? 'approve' : 'reject');

    await this.prisma.$transaction([
      this.prisma.phaseReview.create({
        data: {
          companyId,
          phaseId,
          approved: input.approved,
          reviewedById: principal.userId,
          notes: input.reviewNotes ?? null,
        },
      }),
      this.prisma.projectPhase.update({
        where: { id_companyId: { id: phaseId, companyId } },
        data: { status: next },
      }),
    ]);

    // Returns the whole project: approving the last phase changes the derived
    // project status too, and the client needs both in one round trip.
    const project = await this.prisma.project.findFirstOrThrow({
      where: { id: projectId, companyId },
      include: projectInclude,
    });
    return toProjectDto(project, this.mapperOptions);
  }

  async listReports(
    companyId: string,
    projectId: string,
    phaseId: string,
  ): Promise<PhaseReportSummaryDto[]> {
    await this.findPhaseOrThrow(companyId, projectId, phaseId);

    const reports = await this.prisma.workerReport.findMany({
      where: { companyId, phaseId },
      orderBy: { submittedAt: 'desc' },
      include: {
        employee: { select: { name: true } },
        media: { include: { media: { select: { id: true } } } },
      },
    });

    const base = this.config.storagePublicBaseUrl;
    return reports.map((report) => {
      const photos = report.media.filter((m) => m.slot === 'reportPhoto');
      const memo = report.media.find((m) => m.slot === 'reportVoiceMemo');
      return {
        id: report.id,
        employeeId: report.employeeId,
        employeeName: report.employee?.name ?? report.employeeNameSnapshot,
        description: report.description,
        submittedAt: report.submittedAt.toISOString(),
        photoCount: photos.length,
        hasVoiceMemo: Boolean(memo),
        photoUrls: photos.map((p) => `${base}/media/${p.media.id}/content`),
        voiceMemoUrl: memo ? `${base}/media/${memo.media.id}/content` : null,
      };
    });
  }

  // --- helpers -------------------------------------------------------------

  private async findPhaseOrThrow(
    companyId: string,
    projectId: string,
    phaseId: string,
  ): Promise<{ id: string; status: Prisma.ProjectPhaseGetPayload<object>['status']; startDate: Date; endDate: Date }> {
    const phase = await this.prisma.projectPhase.findFirst({
      where: { id: phaseId, projectId, companyId, deletedAt: null },
      select: { id: true, status: true, startDate: true, endDate: true },
    });
    if (!phase) throw AppException.notFound('Phase', phaseId);
    return phase;
  }

  private async assertEmployeesExist(companyId: string, employeeIds: string[]): Promise<void> {
    const unique = [...new Set(employeeIds)].filter((id) => id.length > 0);
    if (unique.length === 0) return;
    const found = await this.prisma.employee.findMany({
      where: { companyId, deletedAt: null, id: { in: unique } },
      select: { id: true },
    });
    if (found.length !== unique.length) {
      const known = new Set(found.map((e) => e.id));
      throw AppException.badRequest(
        `Unknown employee(s): ${unique.filter((id) => !known.has(id)).join(', ')}.`,
        'assignedEmployeeIds',
      );
    }
  }
}
