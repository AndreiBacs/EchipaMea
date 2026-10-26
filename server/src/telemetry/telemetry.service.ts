import { Injectable, Logger } from '@nestjs/common';
import type { Prisma } from '@prisma/client';
import { AppConfig } from '../common/config/configuration';
import { PrismaService } from '../common/prisma/prisma.service';
import { dayKeyToDate } from '../common/util/day-key';
import type {
  ArrivalListQuery,
  ArrivalsDto,
  LatestLocationsDto,
  LocationTrailDto,
  TelemetryWindowQuery,
} from './dto/telemetry.dto';

const DEFAULT_WINDOW_HOURS = 24;

@Injectable()
export class TelemetryService {
  private readonly logger = new Logger(TelemetryService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly config: AppConfig,
  ) {}

  /**
   * The location trail for a window.
   *
   * Bounded by default rather than open-ended: without a `from` this would scan
   * the entire retention period, which grows without limit as the crew works.
   */
  async trail(companyId: string, query: TelemetryWindowQuery): Promise<LocationTrailDto> {
    const to = query.to ?? new Date();
    const from = query.from ?? new Date(to.getTime() - DEFAULT_WINDOW_HOURS * 3600_000);

    const where: Prisma.WorkerLocationSampleWhereInput = {
      companyId,
      ...(query.employeeId ? { employeeId: query.employeeId } : {}),
      capturedAt: { gte: from, lte: to },
    };

    const [rows, total] = await Promise.all([
      this.prisma.workerLocationSample.findMany({
        where,
        orderBy: [{ capturedAt: 'desc' }],
        take: query.limit,
      }),
      this.prisma.workerLocationSample.count({ where }),
    ]);

    return {
      items: rows.map((row) => ({
        employeeId: row.employeeId,
        employeeName: row.employeeNameSnapshot,
        latitude: row.latitude,
        longitude: row.longitude,
        accuracyMeters: row.accuracyMeters,
        capturedAt: row.capturedAt.toISOString(),
        receivedAt: row.receivedAt.toISOString(),
      })),
      page: { limit: query.limit, total },
      from: from.toISOString(),
      to: to.toISOString(),
    };
  }

  /**
   * Where everyone was last seen -- one row per employee, for a map.
   *
   * "Last seen" is the most recently *received* fix, not the greatest
   * `capturedAt`. That distinction matters: `capturedAt` is the device's own
   * wall clock, and a phone with a skewed clock -- or one that simply has the
   * year wrong -- would otherwise pin itself to the top of this list forever,
   * with every genuinely newer fix looking older than it. `receivedAt` is
   * server-assigned and cannot be influenced by the client. Both are reported so
   * a stale device clock is visible rather than hidden.
   *
   * Done as a groupBy and then a targeted fetch, rather than one query per
   * employee. Postgres could do this in a single `DISTINCT ON`, but that needs
   * `$queryRaw`, which steps outside the Prisma client extension that enforces
   * `companyId`. Two safe queries beat one raw one on a tenancy-critical path.
   */
  async latest(companyId: string): Promise<LatestLocationsDto> {
    const grouped = await this.prisma.workerLocationSample.groupBy({
      by: ['employeeId'],
      where: { companyId },
      _max: { receivedAt: true },
    });
    if (grouped.length === 0) return { items: [] };

    const rows = await this.prisma.workerLocationSample.findMany({
      where: {
        companyId,
        OR: grouped
          .filter((g) => g._max.receivedAt !== null)
          .map((g) => ({ employeeId: g.employeeId, receivedAt: g._max.receivedAt as Date })),
      },
    });

    // A batch flush writes many rows with the same `receivedAt`, so one employee
    // can still match more than once here. Break the tie on the device's own
    // clock, which is the best available answer to "which of these is newest".
    const newestPerEmployee = new Map<string, (typeof rows)[number]>();
    for (const row of rows) {
      const held = newestPerEmployee.get(row.employeeId);
      if (!held || row.capturedAt > held.capturedAt) {
        newestPerEmployee.set(row.employeeId, row);
      }
    }

    const now = Date.now();
    const items = [...newestPerEmployee.values()]
      .map((row) => ({
        employeeId: row.employeeId,
        employeeName: row.employeeNameSnapshot,
        latitude: row.latitude,
        longitude: row.longitude,
        accuracyMeters: row.accuracyMeters,
        capturedAt: row.capturedAt.toISOString(),
        receivedAt: row.receivedAt.toISOString(),
        // From `receivedAt`, for the same reason the ordering is: a device that
        // thinks it is next year must not report itself as zero seconds old.
        ageSeconds: Math.max(0, Math.round((now - row.receivedAt.getTime()) / 1000)),
        clockSkewSeconds: Math.round((row.capturedAt.getTime() - row.receivedAt.getTime()) / 1000),
      }))
      .sort((a, b) => a.ageSeconds - b.ageSeconds);

    return { items };
  }

  /** Who turned up where, and when. */
  async arrivals(companyId: string, query: ArrivalListQuery): Promise<ArrivalsDto> {
    const where: Prisma.WorkerArrivalWhereInput = {
      companyId,
      ...(query.projectId ? { projectId: query.projectId } : {}),
      ...(query.employeeId ? { employeeId: query.employeeId } : {}),
      ...(query.day ? { arrivedAt: dayBounds(query.day) } : {}),
    };

    const [rows, total] = await Promise.all([
      this.prisma.workerArrival.findMany({
        where,
        orderBy: [{ arrivedAt: 'desc' }],
        take: query.limit,
        include: {
          project: { select: { name: true } },
          employee: { select: { name: true } },
        },
      }),
      this.prisma.workerArrival.count({ where }),
    ]);

    return {
      items: rows.map((row) => ({
        id: row.id,
        projectId: row.projectId,
        projectName: row.project.name,
        employeeId: row.employeeId,
        employeeName: row.employee.name,
        arrivedAt: row.arrivedAt.toISOString(),
      })),
      page: { limit: query.limit, total },
    };
  }

  /**
   * Retention sweep for the location trail. Measured on `receivedAt`, which the
   * server assigns: `capturedAt` is the phone's clock, and a wrong one would
   * otherwise delete fresh samples early or keep old ones past retention.
   */
  async pruneOldSamples(): Promise<number> {
    const days = this.config.locationSampleRetentionDays;
    if (days <= 0) return 0;
    const cutoff = new Date(Date.now() - days * 24 * 3600_000);
    const result = await this.prisma.workerLocationSample.deleteMany({
      where: { receivedAt: { lt: cutoff } },
    });
    if (result.count > 0) {
      this.logger.log(`Pruned ${result.count} location sample(s) older than ${days}d.`);
    }
    return result.count;
  }
}

/**
 * A calendar day as an instant range.
 *
 * `dayKeyToDate` builds UTC midnight, so this is a UTC day. Arrivals are
 * timestamps rather than the bare dates a sequence uses, and a "day" for a
 * crew working one site is unambiguous enough at that resolution; a per-company
 * timezone is the honest fix and is not modelled yet.
 */
function dayBounds(day: string): { gte: Date; lt: Date } {
  const start = dayKeyToDate(day);
  return { gte: start, lt: new Date(start.getTime() + 24 * 3600_000) };
}
