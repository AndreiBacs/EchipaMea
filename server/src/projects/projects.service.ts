import { Injectable } from '@nestjs/common';
import type { Prisma } from '@prisma/client';
import { AppConfig } from '../common/config/configuration';
import { AppException } from '../common/errors/app-exception';
import { PrismaService } from '../common/prisma/prisma.service';
import { MediaService } from '../media/media.service';
import {
  buildPage,
  cursorFilter,
  encodeCursor,
  parseDateSortKey,
  type Paged,
} from '../common/dto/page.dto';
import { dayKeyToDate } from '../common/util/day-key';
import { deriveFromPhases } from './project-status.service';
import { projectInclude, toProjectDto, type ProjectWithRelations } from './project.mapper';
import type {
  InlinePhaseInput,
  ProjectCreateRequest,
  ProjectDto,
  ProjectListQuery,
  ProjectUpdateRequest,
} from './dto/project.dto';

@Injectable()
export class ProjectsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly media: MediaService,
    private readonly config: AppConfig,
  ) {}

  private get mapperOptions() {
    return { mediaBaseUrl: this.config.storagePublicBaseUrl };
  }

  async list(companyId: string, query: ProjectListQuery): Promise<Paged<ProjectDto>> {
    const descending = query.sort.startsWith('-');
    const sortField = descending ? query.sort.slice(1) : query.sort;

    const where: Prisma.ProjectWhereInput = {
      companyId,
      deletedAt: null,
      ...(query.clientId ? { clientId: query.clientId } : {}),
      ...(query.q ? { name: { contains: query.q, mode: 'insensitive' } } : {}),
      ...(query.assignedEmployeeId
        ? {
            // Assigned at project level OR to any of its phases: the app treats
            // both as "this worker is on this job".
            OR: [
              { assignments: { some: { employeeId: query.assignedEmployeeId } } },
              {
                phases: {
                  some: {
                    deletedAt: null,
                    assignments: { some: { employeeId: query.assignedEmployeeId } },
                  },
                },
              },
            ],
          }
        : {}),
    };

    const resume = cursorFilter({
      sortField,
      descending,
      cursor: query.cursor,
      parseSortKey: sortField === 'createdAt' ? parseDateSortKey : undefined,
    });
    if (resume) {
      // `assignedEmployeeId` may already own `where.OR`; AND them so both hold.
      where.AND = [...(where.AND ? asArray(where.AND) : []), { OR: resume }];
    }

    const rows = await this.prisma.project.findMany({
      where,
      orderBy: [{ [sortField]: descending ? 'desc' : 'asc' }, { id: descending ? 'desc' : 'asc' }],
      take: query.limit + 1,
      include: projectInclude,
    });

    const total = query.withTotal
      ? await this.prisma.project.count({ where: { companyId, deletedAt: null } })
      : undefined;

    const page = buildPage(
      rows,
      query.limit,
      (row) =>
        encodeCursor(sortField === 'createdAt' ? row.createdAt.toISOString() : row.name, row.id),
      total,
    );

    let items = page.items.map((row) => toProjectDto(row, this.mapperOptions));

    // Status is derived, so it cannot be a SQL filter -- it is applied after
    // mapping. Documented as a post-filter because it interacts with paging:
    // a page may return fewer than `limit` items when this is set.
    if (query.status) {
      items = items.filter((item) => item.status === query.status);
    }

    return { items, page: page.page };
  }

  async getById(companyId: string, projectId: string): Promise<ProjectDto> {
    return toProjectDto(await this.findOrThrow(companyId, projectId), this.mapperOptions);
  }

  async create(companyId: string, input: ProjectCreateRequest): Promise<ProjectDto> {
    await this.assertClientExists(companyId, input.clientId);
    await this.assertEmployeesExist(companyId, [
      ...input.assignedEmployeeIds,
      ...input.phases.flatMap((p) => p.assignedEmployeeIds),
    ]);
    await this.media.assertOwned(
      companyId,
      input.phases.flatMap((p) =>
        p.workInstructions.flatMap((i) => [...i.photoMediaIds, ...i.audioMediaIds]),
      ),
    );

    const created = await this.prisma.$transaction(async (tx) => {
      const project = await tx.project.create({
        data: {
          companyId,
          clientId: input.clientId,
          name: input.name,
          useClientAddress: input.useClientAddress,
          addressLine1: input.addressLine1,
          city: input.city,
          state: input.state,
          zipCode: input.zipCode,
          latitude: input.latitude ?? null,
          longitude: input.longitude ?? null,
        },
      });

      await this.replaceProjectAssignments(tx, companyId, project.id, input.assignedEmployeeIds);

      for (const [index, phase] of input.phases.entries()) {
        await this.createPhase(tx, companyId, project.id, phase, index);
      }

      return project.id;
    });

    return this.getById(companyId, created);
  }

  async update(
    companyId: string,
    projectId: string,
    input: ProjectUpdateRequest,
  ): Promise<ProjectDto> {
    await this.findOrThrow(companyId, projectId);
    if (input.clientId) await this.assertClientExists(companyId, input.clientId);
    if (input.assignedEmployeeIds) {
      await this.assertEmployeesExist(companyId, input.assignedEmployeeIds);
    }

    await this.prisma.$transaction(async (tx) => {
      await tx.project.update({
        where: { id_companyId: { id: projectId, companyId } },
        data: {
          ...(input.name !== undefined ? { name: input.name } : {}),
          ...(input.clientId !== undefined ? { clientId: input.clientId } : {}),
          ...(input.useClientAddress !== undefined
            ? { useClientAddress: input.useClientAddress }
            : {}),
          ...(input.addressLine1 !== undefined ? { addressLine1: input.addressLine1 } : {}),
          ...(input.city !== undefined ? { city: input.city } : {}),
          ...(input.state !== undefined ? { state: input.state } : {}),
          ...(input.zipCode !== undefined ? { zipCode: input.zipCode } : {}),
          ...(input.latitude !== undefined ? { latitude: input.latitude } : {}),
          ...(input.longitude !== undefined ? { longitude: input.longitude } : {}),
        },
      });

      // Present means replace the whole set; omitted means leave untouched.
      if (input.assignedEmployeeIds !== undefined) {
        await this.replaceProjectAssignments(tx, companyId, projectId, input.assignedEmployeeIds);
      }
    });

    return this.getById(companyId, projectId);
  }

  /**
   * Manual "mark as done".
   *
   * Recorded as `closedAt` rather than by writing a status column, so the phase
   * truth is never overwritten: clearing the override restores the derived
   * value instead of leaving a stale `done`.
   */
  async markDone(companyId: string, projectId: string): Promise<ProjectDto> {
    await this.findOrThrow(companyId, projectId);
    await this.prisma.project.update({
      where: { id_companyId: { id: projectId, companyId } },
      data: { closedAt: new Date() },
    });
    return this.getById(companyId, projectId);
  }

  async reopen(companyId: string, projectId: string): Promise<ProjectDto> {
    await this.findOrThrow(companyId, projectId);
    await this.prisma.project.update({
      where: { id_companyId: { id: projectId, companyId } },
      data: { closedAt: null },
    });
    return this.getById(companyId, projectId);
  }

  async remove(companyId: string, projectId: string): Promise<void> {
    await this.findOrThrow(companyId, projectId);
    const now = new Date();
    await this.prisma.$transaction([
      this.prisma.project.update({
        where: { id_companyId: { id: projectId, companyId } },
        data: { deletedAt: now },
      }),
      this.prisma.projectPhase.updateMany({
        where: { companyId, projectId, deletedAt: null },
        data: { deletedAt: now },
      }),
      // Manual day orders for a deleted project are meaningless.
      this.prisma.dailySequenceOverride.deleteMany({ where: { companyId, projectId } }),
    ]);
  }

  /** Derived status of one project, without building the whole DTO. */
  async deriveStatus(companyId: string, projectId: string): Promise<string> {
    const project = await this.prisma.project.findFirst({
      where: { id: projectId, companyId, deletedAt: null },
      select: { closedAt: true, phases: { where: { deletedAt: null }, select: { status: true } } },
    });
    if (!project) throw AppException.notFound('Project', projectId);
    return project.closedAt ? 'done' : deriveFromPhases(project.phases);
  }

  async findOrThrow(companyId: string, projectId: string): Promise<ProjectWithRelations> {
    const row = await this.prisma.project.findFirst({
      where: { id: projectId, companyId, deletedAt: null },
      include: projectInclude,
    });
    if (!row) throw AppException.notFound('Project', projectId);
    return row;
  }

  // --- helpers -------------------------------------------------------------

  private async assertClientExists(companyId: string, clientId: string): Promise<void> {
    const found = await this.prisma.client.count({
      where: { id: clientId, companyId, deletedAt: null },
    });
    if (found === 0) {
      throw AppException.badRequest(`Client "${clientId}" does not exist.`, 'clientId');
    }
  }

  /**
   * Validates employee references in one query.
   *
   * Without this, an unknown id would surface as a raw foreign-key violation,
   * and -- worse -- an id belonging to *another tenant* would be accepted by the
   * FK but silently leak that employee into this company's project.
   */
  private async assertEmployeesExist(companyId: string, employeeIds: string[]): Promise<void> {
    const unique = [...new Set(employeeIds)].filter((id) => id.length > 0);
    if (unique.length === 0) return;

    const found = await this.prisma.employee.findMany({
      where: { companyId, deletedAt: null, id: { in: unique } },
      select: { id: true },
    });
    if (found.length !== unique.length) {
      const known = new Set(found.map((e) => e.id));
      const missing = unique.filter((id) => !known.has(id));
      throw AppException.badRequest(
        `Unknown employee(s): ${missing.join(', ')}.`,
        'assignedEmployeeIds',
      );
    }
  }

  private async replaceProjectAssignments(
    tx: Prisma.TransactionClient,
    companyId: string,
    projectId: string,
    employeeIds: string[],
  ): Promise<void> {
    const unique = [...new Set(employeeIds)].filter((id) => id.length > 0);
    await tx.projectAssignment.deleteMany({ where: { projectId } });
    if (unique.length === 0) return;
    await tx.projectAssignment.createMany({
      data: unique.map((employeeId) => ({ projectId, employeeId, companyId })),
      skipDuplicates: true,
    });
  }

  /** Shared with the phases module so inline and standalone creation agree. */
  async createPhase(
    tx: Prisma.TransactionClient,
    companyId: string,
    projectId: string,
    input: InlinePhaseInput,
    sortIndex: number,
  ): Promise<string> {
    const startDate = dayKeyToDate(input.startDate);
    const endDate = dayKeyToDate(input.endDate);
    if (endDate.getTime() < startDate.getTime()) {
      throw AppException.badRequest('Phase end date cannot precede its start date.', 'endDate');
    }

    const phase = await tx.projectPhase.create({
      data: {
        ...(input.id ? { id: input.id } : {}),
        companyId,
        projectId,
        name: input.name,
        startDate,
        endDate,
        description: input.description,
        status: 'notStarted',
        sortIndex,
      },
    });

    const assignees = [...new Set(input.assignedEmployeeIds)].filter((id) => id.length > 0);
    if (assignees.length > 0) {
      await tx.phaseAssignment.createMany({
        data: assignees.map((employeeId) => ({
          phaseId: phase.id,
          employeeId,
          companyId,
          projectId,
        })),
        skipDuplicates: true,
      });
    }

    for (const [index, instruction] of input.workInstructions.entries()) {
      const created = await tx.phaseWorkInstruction.create({
        data: {
          ...(instruction.id ? { id: instruction.id } : {}),
          companyId,
          phaseId: phase.id,
          text: instruction.text,
          sortIndex: index,
        },
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
          data: links.map((link) => ({ ...link, instructionId: created.id, companyId })),
          skipDuplicates: true,
        });
      }
    }

    return phase.id;
  }
}

function asArray<T>(value: T | T[]): T[] {
  return Array.isArray(value) ? value : [value];
}
