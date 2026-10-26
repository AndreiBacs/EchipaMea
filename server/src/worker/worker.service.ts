import { Injectable, Logger } from '@nestjs/common';
import type { Prisma } from '@prisma/client';
import { AppConfig } from '../common/config/configuration';
import { AppException } from '../common/errors/app-exception';
import { PrismaService } from '../common/prisma/prisma.service';
import { parseFlexibleIso } from '../common/util/iso';
import type { Principal } from '../common/auth/principal';
import type { ProjectDto } from '../projects/dto/project.dto';
import { projectInclude, toProjectDto } from '../projects/project.mapper';
import { ConnectionRegistryService } from '../realtime/connection-registry.service';
import { compareWorkerProjects, selectFreshSamples } from './worker-ordering';
import type {
  ArrivalCreateRequest,
  LocationBatchRequest,
  LocationBatchResultDto,
  WorkerArrivalDto,
  WorkerProfileDto,
  WorkerProjectsDto,
  WorkerProjectsQuery,
} from './dto/worker.dto';

/**
 * Repeat taps on "I have arrived" inside this window collapse into the first
 * one. The button is a big target on a phone at a noisy building site, and a
 * second tap should not put a second row in front of the foreman.
 */
const ARRIVAL_DEDUPE_MINUTES = 15;

@Injectable()
export class WorkerService {
  private readonly logger = new Logger(WorkerService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly realtime: ConnectionRegistryService,
    private readonly config: AppConfig,
  ) {}

  private get mapperOptions() {
    return { mediaBaseUrl: this.config.storagePublicBaseUrl };
  }

  // --- Identity ------------------------------------------------------------

  /**
   * Every endpoint here is "about me", so a worker identity is non-negotiable.
   *
   * A foreman token reaches this far -- it is authenticated and belongs to the
   * company -- but has no employee to be "me", so it is refused rather than
   * silently handed an empty list.
   */
  private employeeIdOf(principal: Principal): string {
    if (principal.kind !== 'employee') {
      throw AppException.forbidden(
        'This endpoint needs a worker session. Sign in by scanning a QR login code.',
      );
    }
    return principal.employeeId;
  }

  async profile(principal: Principal): Promise<WorkerProfileDto> {
    const employeeId = this.employeeIdOf(principal);

    const employee = await this.prisma.employee.findFirst({
      where: { id: employeeId, companyId: principal.companyId, deletedAt: null },
      include: { company: { select: { id: true, name: true } } },
    });
    if (!employee) throw AppException.notFound('Employee', employeeId);

    return {
      employeeId: employee.id,
      name: employee.name,
      role: employee.role,
      email: employee.email,
      phone: employee.phone,
      workStartHour: employee.workStartHour,
      workEndHour: employee.workEndHour,
      workingDays: employee.workingDays,
      latitude: employee.latitude,
      longitude: employee.longitude,
      companyId: employee.company.id,
      companyName: employee.company.name,
    };
  }

  // --- Projects ------------------------------------------------------------

  /**
   * Assigned at project level, or to any live phase of it.
   *
   * The app has a third fallback -- match the worker's display name against
   * `project.workers` -- for older demo projects that carry no employee ids.
   * It is deliberately not reproduced. Server-side `workers` is *derived from*
   * those very assignments, so a name can only appear there if the employee is
   * already assigned; the fallback could not match anything the first two
   * clauses miss, and matching people by display name is a bug waiting for two
   * employees called Ion P.
   */
  private assignedTo(employeeId: string): Prisma.ProjectWhereInput {
    return {
      OR: [
        { assignments: { some: { employeeId } } },
        {
          phases: {
            some: { deletedAt: null, assignments: { some: { employeeId } } },
          },
        },
      ],
    };
  }

  /**
   * The worker's own job list.
   *
   * Replaces `worker_assigned_projects_provider.dart`, which pulls the whole
   * company project list and filters on the device. In a multi-tenant product
   * that is a data-exposure problem before it is a bandwidth one: every worker
   * phone holds every client, address and phase in the company.
   *
   * Not cursor-paginated, unlike `/projects`. Both the filter (`status`) and the
   * sort key are *derived*, so no SQL cursor can express the boundary and a
   * cursor over it would skip or repeat rows as phases change. A worker's
   * assignment list is small and bounded, so it is capped and returned whole.
   */
  async projects(principal: Principal, query: WorkerProjectsQuery): Promise<WorkerProjectsDto> {
    const employeeId = this.employeeIdOf(principal);

    const rows = await this.prisma.project.findMany({
      where: {
        companyId: principal.companyId,
        deletedAt: null,
        ...this.assignedTo(employeeId),
      },
      include: projectInclude,
      // A bounded over-fetch: `done` is filtered after mapping, so the cap has
      // to be applied to the mapped list rather than to the query.
      take: 500,
    });

    let items: ProjectDto[] = rows.map((row) => toProjectDto(row, this.mapperOptions));
    if (!query.includeDone) {
      items = items.filter((item) => item.status !== 'done');
    }

    items.sort(compareWorkerProjects);

    const total = items.length;
    return { items: items.slice(0, query.limit), page: { limit: query.limit, total } };
  }

  /**
   * One project, but only if it is the worker's.
   *
   * A project that exists and belongs to someone else answers 404, not 403: a
   * 403 would confirm the id is real, turning this into a way to enumerate the
   * company's projects one guess at a time.
   */
  async project(principal: Principal, projectId: string): Promise<ProjectDto> {
    const employeeId = this.employeeIdOf(principal);

    const row = await this.prisma.project.findFirst({
      where: {
        id: projectId,
        companyId: principal.companyId,
        deletedAt: null,
        ...this.assignedTo(employeeId),
      },
      include: projectInclude,
    });
    if (!row) throw AppException.notFound('Project', projectId);

    return toProjectDto(row, this.mapperOptions);
  }

  // --- Arrivals ------------------------------------------------------------

  /**
   * "I have arrived on site."
   *
   * Today this button writes to `worker_foreman_inbox_controller.dart`, whose
   * state nothing ever reads -- the worker taps it, gets a confirmation
   * snackbar, and the foreman is never told. This is the endpoint that makes
   * that button do something.
   */
  async announceArrival(
    principal: Principal,
    input: ArrivalCreateRequest,
  ): Promise<WorkerArrivalDto> {
    const employeeId = this.employeeIdOf(principal);
    const companyId = principal.companyId;

    // Reuses the same assignment rule as the job list: a worker can only
    // announce arrival at a job they are actually on.
    const project = await this.prisma.project.findFirst({
      where: {
        id: input.projectId,
        companyId,
        deletedAt: null,
        ...this.assignedTo(employeeId),
      },
      select: { id: true, name: true },
    });
    if (!project) throw AppException.notFound('Project', input.projectId);

    const employee = await this.prisma.employee.findFirst({
      where: { id: employeeId, companyId, deletedAt: null },
      select: { id: true, name: true },
    });
    if (!employee) throw AppException.notFound('Employee', employeeId);

    const arrivedAt = input.arrivedAt
      ? (parseFlexibleIso(input.arrivedAt) ?? new Date())
      : new Date();

    const recent = await this.prisma.workerArrival.findFirst({
      where: {
        companyId,
        projectId: project.id,
        employeeId,
        // Both bounds: `arrivedAt` may be backdated (an offline tap flushed later),
        // and a tap 40 minutes *before* an existing arrival is a separate one.
        arrivedAt: {
          gte: new Date(arrivedAt.getTime() - ARRIVAL_DEDUPE_MINUTES * 60_000),
          lte: new Date(arrivedAt.getTime() + ARRIVAL_DEDUPE_MINUTES * 60_000),
        },
      },
      orderBy: { arrivedAt: 'desc' },
      select: { id: true, arrivedAt: true },
    });
    if (recent) {
      return {
        id: recent.id,
        projectId: project.id,
        employeeId,
        arrivedAt: recent.arrivedAt.toISOString(),
        duplicate: true,
      };
    }

    const arrival = await this.prisma.$transaction(async (tx) => {
      const created = await tx.workerArrival.create({
        data: { companyId, projectId: project.id, employeeId, arrivedAt },
      });

      const foremen = await tx.user.findMany({
        where: { companyId, deletedAt: null, isActive: true },
        select: { id: true },
      });
      if (foremen.length > 0) {
        await tx.notification.createMany({
          data: foremen.map((user) => ({
            companyId,
            recipientUserId: user.id,
            kind: 'workerArrived' as const,
            // Structured, never a rendered sentence: the app localises into
            // ro/hu/en and a server-built string would bypass that.
            payload: {
              projectId: project.id,
              projectName: project.name,
              employeeId,
              employeeName: employee.name,
            },
            projectId: project.id,
            employeeId,
            occurredAt: arrivedAt,
          })),
        });
      }

      return created;
    });

    const delivered = this.realtime.publishToForemen(companyId, {
      type: 'worker_arrived',
      projectId: project.id,
      projectName: project.name,
      employeeId,
      employeeName: employee.name,
      arrivedAt: arrivedAt.toISOString(),
    });
    this.logger.log(
      `${employee.name} arrived at ${project.name}; pushed to ${delivered} foreman socket(s).`,
    );

    return {
      id: arrival.id,
      projectId: project.id,
      employeeId,
      arrivedAt: arrival.arrivedAt.toISOString(),
      duplicate: false,
    };
  }

  // --- Telemetry fallback --------------------------------------------------

  /**
   * Batch location upload: the offline outbox flush.
   *
   * The socket only carries fixes while the app is open and connected. This is
   * the catch-up path, and it must be safe to retry -- a client that never saw
   * the response will send the same batch again. There is no unique constraint
   * to lean on, so duplicates are detected by comparing `capturedAt` against
   * what is already stored in the batch's own time range.
   */
  async recordLocations(
    principal: Principal,
    input: LocationBatchRequest,
  ): Promise<LocationBatchResultDto> {
    const employeeId = this.employeeIdOf(principal);
    const companyId = principal.companyId;

    const employee = await this.prisma.employee.findFirst({
      where: { id: employeeId, companyId, deletedAt: null },
      select: { id: true, name: true },
    });
    if (!employee) throw AppException.notFound('Employee', employeeId);

    const samples = input.samples.map((sample) => ({
      ...sample,
      capturedAtDate: parseFlexibleIso(sample.capturedAt) ?? new Date(),
    }));

    const times = samples.map((s) => s.capturedAtDate.getTime());
    const existing = await this.prisma.workerLocationSample.findMany({
      where: {
        companyId,
        employeeId,
        capturedAt: { gte: new Date(Math.min(...times)), lte: new Date(Math.max(...times)) },
      },
      select: { capturedAt: true },
    });
    const { fresh, duplicates } = selectFreshSamples(
      samples,
      existing.map((row) => row.capturedAt.getTime()),
    );

    if (fresh.length > 0) {
      await this.prisma.workerLocationSample.createMany({
        data: fresh.map((sample) => ({
          companyId,
          employeeId,
          latitude: sample.latitude,
          longitude: sample.longitude,
          accuracyMeters: sample.accuracyMeters,
          capturedAt: sample.capturedAtDate,
          employeeNameSnapshot: employee.name,
        })),
      });
    }

    return { accepted: fresh.length, duplicates };
  }
}
