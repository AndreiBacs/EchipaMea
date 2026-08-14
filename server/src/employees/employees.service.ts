import { Injectable } from '@nestjs/common';
import type { Prisma } from '@prisma/client';
import { TokenService } from '../auth/token.service';
import { AppException } from '../common/errors/app-exception';
import { PrismaService } from '../common/prisma/prisma.service';
import {
  buildPage,
  cursorFilter,
  encodeCursor,
  parseDateSortKey,
  type Paged,
} from '../common/dto/page.dto';
import type {
  EmployeeCreateRequest,
  EmployeeDto,
  EmployeeListQuery,
  EmployeeUpdateRequest,
} from './dto/employee.dto';

@Injectable()
export class EmployeesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly tokens: TokenService,
  ) {}

  async list(companyId: string, query: EmployeeListQuery): Promise<Paged<EmployeeDto>> {
    const descending = query.sort.startsWith('-');
    const sortField = descending ? query.sort.slice(1) : query.sort;

    const where: Prisma.EmployeeWhereInput = {
      companyId,
      deletedAt: null,
      ...(query.role ? { role: query.role } : {}),
      ...(query.active === undefined ? {} : { isActive: query.active }),
      ...(query.q ? { name: { contains: query.q, mode: 'insensitive' } } : {}),
    };

    const resume = cursorFilter({
      sortField,
      descending,
      cursor: query.cursor,
      parseSortKey: sortField === 'createdAt' ? parseDateSortKey : undefined,
    });
    if (resume) where.OR = resume;

    const rows = await this.prisma.employee.findMany({
      where,
      orderBy: [{ [sortField]: descending ? 'desc' : 'asc' }, { id: descending ? 'desc' : 'asc' }],
      take: query.limit + 1,
      select: employeeSelect,
    });

    const total = query.withTotal
      ? await this.prisma.employee.count({ where: { companyId, deletedAt: null } })
      : undefined;

    const page = buildPage(
      rows,
      query.limit,
      (row) =>
        encodeCursor(sortField === 'createdAt' ? row.createdAt.toISOString() : row.name, row.id),
      total,
    );

    return { items: page.items.map(toDto), page: page.page };
  }

  async getById(companyId: string, employeeId: string): Promise<EmployeeDto> {
    const row = await this.prisma.employee.findFirst({
      where: { id: employeeId, companyId, deletedAt: null },
      select: employeeSelect,
    });
    if (!row) throw AppException.notFound('Employee', employeeId);
    return toDto(row);
  }

  async create(companyId: string, input: EmployeeCreateRequest): Promise<EmployeeDto> {
    const row = await this.prisma.employee.create({
      data: {
        companyId,
        name: input.name,
        role: input.role,
        email: input.email,
        phone: input.phone,
        workStartHour: input.workStartHour,
        workEndHour: input.workEndHour,
        workingDays: input.workingDays,
        latitude: input.latitude ?? null,
        longitude: input.longitude ?? null,
        isActive: input.isActive,
      },
      select: employeeSelect,
    });
    return toDto(row);
  }

  async update(
    companyId: string,
    employeeId: string,
    input: EmployeeUpdateRequest,
  ): Promise<EmployeeDto> {
    const existing = await this.prisma.employee.findFirst({
      where: { id: employeeId, companyId, deletedAt: null },
      select: { id: true, workStartHour: true, workEndHour: true, isActive: true },
    });
    if (!existing) throw AppException.notFound('Employee', employeeId);

    // The zero-length-shift rule spans two fields, so it has to be re-checked
    // against the merged result rather than the patch alone.
    const nextStart = input.workStartHour ?? existing.workStartHour;
    const nextEnd = input.workEndHour ?? existing.workEndHour;
    if (nextStart === nextEnd) {
      throw AppException.badRequest(
        'Start and end hour cannot be equal: that describes a zero-length shift.',
        'workEndHour',
      );
    }

    const row = await this.prisma.employee.update({
      where: { id_companyId: { id: employeeId, companyId } },
      data: {
        ...(input.name !== undefined ? { name: input.name } : {}),
        ...(input.role !== undefined ? { role: input.role } : {}),
        ...(input.email !== undefined ? { email: input.email } : {}),
        ...(input.phone !== undefined ? { phone: input.phone } : {}),
        ...(input.workStartHour !== undefined ? { workStartHour: input.workStartHour } : {}),
        ...(input.workEndHour !== undefined ? { workEndHour: input.workEndHour } : {}),
        ...(input.workingDays !== undefined ? { workingDays: input.workingDays } : {}),
        // `null` clears, `undefined` leaves untouched.
        ...(input.latitude !== undefined ? { latitude: input.latitude } : {}),
        ...(input.longitude !== undefined ? { longitude: input.longitude } : {}),
        ...(input.isActive !== undefined ? { isActive: input.isActive } : {}),
      },
      select: employeeSelect,
    });

    // Deactivating must also end live sessions; otherwise the worker's JWT keeps
    // working until it expires, which for a worker token is up to 12 hours.
    if (input.isActive === false && existing.isActive) {
      await this.tokens.revokeAllForSubject(companyId, { employeeId });
    }

    return toDto(row);
  }

  /**
   * Soft delete.
   *
   * The row is retained because assignments, submissions and report history all
   * reference it -- a hard delete would erase who did what. Sessions are revoked
   * so the worker loses access immediately.
   */
  async remove(companyId: string, employeeId: string): Promise<void> {
    const found = await this.prisma.employee.count({
      where: { id: employeeId, companyId, deletedAt: null },
    });
    if (found === 0) throw AppException.notFound('Employee', employeeId);

    await this.prisma.employee.update({
      where: { id_companyId: { id: employeeId, companyId } },
      data: { deletedAt: new Date(), isActive: false },
    });

    await this.tokens.revokeAllForSubject(companyId, { employeeId });
  }
}

const employeeSelect = {
  id: true,
  name: true,
  role: true,
  email: true,
  phone: true,
  workStartHour: true,
  workEndHour: true,
  workingDays: true,
  latitude: true,
  longitude: true,
  isActive: true,
  createdAt: true,
  updatedAt: true,
} satisfies Prisma.EmployeeSelect;

type EmployeeRow = Prisma.EmployeeGetPayload<{ select: typeof employeeSelect }>;

export function toDto(row: EmployeeRow): EmployeeDto {
  return {
    id: row.id,
    name: row.name,
    role: row.role,
    email: row.email,
    phone: row.phone,
    workStartHour: row.workStartHour,
    workEndHour: row.workEndHour,
    workingDays: row.workingDays,
    latitude: row.latitude,
    longitude: row.longitude,
    isActive: row.isActive,
    createdAt: row.createdAt.toISOString(),
    updatedAt: row.updatedAt.toISOString(),
  };
}
