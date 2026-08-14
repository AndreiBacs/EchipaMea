import { Injectable } from '@nestjs/common';
import type { Prisma } from '@prisma/client';
import { AppException } from '../common/errors/app-exception';
import { ErrorCode } from '../common/errors/error-codes';
import { PrismaService } from '../common/prisma/prisma.service';
import { buildPage, decodeCursor, encodeCursor, type Paged } from '../common/dto/page.dto';
import { deriveFromPhases } from '../projects/project-status.service';
import type {
  ClientCreateRequest,
  ClientDto,
  ClientListQuery,
  ClientUpdateRequest,
} from './dto/client.dto';

/** Rows needed to compute `activeProjects` without loading whole projects. */
const activeProjectsSelect = {
  projects: {
    where: { deletedAt: null },
    select: {
      closedAt: true,
      phases: { where: { deletedAt: null }, select: { status: true } },
    },
  },
} satisfies Prisma.ClientSelect;

@Injectable()
export class ClientsService {
  constructor(private readonly prisma: PrismaService) {}

  async list(companyId: string, query: ClientListQuery): Promise<Paged<ClientDto>> {
    const where: Prisma.ClientWhereInput = {
      companyId,
      deletedAt: null,
      ...(query.status ? { status: query.status } : {}),
      ...(query.type ? { type: query.type } : {}),
      ...(query.q ? { name: { contains: query.q, mode: 'insensitive' } } : {}),
    };

    const descending = query.sort.startsWith('-');
    const sortField = descending ? query.sort.slice(1) : query.sort;
    const direction: Prisma.SortOrder = descending ? 'desc' : 'asc';

    if (query.cursor) {
      const { sortKey, id } = decodeCursor(query.cursor);
      const boundary =
        sortField === 'createdAt' ? { createdAt: new Date(sortKey) } : { name: sortKey };
      const comparator = descending ? 'lt' : 'gt';
      // Compound boundary: rows strictly past the sort key, plus rows with the
      // same key but a later id. Without the id tie-break, duplicate names
      // would repeat or skip across pages.
      where.OR = [
        sortField === 'createdAt'
          ? { createdAt: { [comparator]: boundary.createdAt } }
          : { name: { [comparator]: boundary.name } },
        {
          ...(sortField === 'createdAt'
            ? { createdAt: boundary.createdAt }
            : { name: boundary.name }),
          id: { [comparator]: id },
        },
      ];
    }

    const rows = await this.prisma.client.findMany({
      where,
      orderBy: [{ [sortField]: direction }, { id: direction }],
      take: query.limit + 1,
      select: { ...clientSelect, ...activeProjectsSelect },
    });

    const total = query.withTotal
      ? await this.prisma.client.count({ where: { companyId, deletedAt: null } })
      : undefined;

    const page = buildPage(
      rows,
      query.limit,
      (row) =>
        encodeCursor(
          sortField === 'createdAt' ? row.createdAt.toISOString() : row.name,
          row.id,
        ),
      total,
    );

    return { items: page.items.map(toDto), page: page.page };
  }

  async getById(companyId: string, clientId: string): Promise<ClientDto> {
    const row = await this.prisma.client.findFirst({
      where: { id: clientId, companyId, deletedAt: null },
      select: { ...clientSelect, ...activeProjectsSelect },
    });
    if (!row) throw AppException.notFound('Client', clientId);
    return toDto(row);
  }

  async create(companyId: string, input: ClientCreateRequest): Promise<ClientDto> {
    const { activeProjects: _ignored, ...data } = input;
    const row = await this.prisma.client.create({
      data: { ...data, companyId },
      select: { ...clientSelect, ...activeProjectsSelect },
    });
    return toDto(row);
  }

  async update(
    companyId: string,
    clientId: string,
    input: ClientUpdateRequest,
  ): Promise<ClientDto> {
    await this.assertExists(companyId, clientId);
    const { activeProjects: _ignored, ...data } = input;
    const row = await this.prisma.client.update({
      where: { id_companyId: { id: clientId, companyId } },
      data,
      select: { ...clientSelect, ...activeProjectsSelect },
    });
    return toDto(row);
  }

  /**
   * Soft delete.
   *
   * Refused while live projects still reference the client: `Project.clientId`
   * is required, so removing the client would orphan work the foreman can still
   * see. Closing the projects first is the deliberate path.
   */
  async remove(companyId: string, clientId: string): Promise<void> {
    await this.assertExists(companyId, clientId);

    const liveProjects = await this.prisma.project.count({
      where: { companyId, clientId, deletedAt: null },
    });
    if (liveProjects > 0) {
      throw AppException.conflict(
        `This client still has ${liveProjects} project(s). Delete or reassign them first.`,
        ErrorCode.CLIENT_HAS_PROJECTS,
      );
    }

    await this.prisma.client.update({
      where: { id_companyId: { id: clientId, companyId } },
      data: { deletedAt: new Date() },
    });
  }

  private async assertExists(companyId: string, clientId: string): Promise<void> {
    const found = await this.prisma.client.count({
      where: { id: clientId, companyId, deletedAt: null },
    });
    if (found === 0) throw AppException.notFound('Client', clientId);
  }
}

const clientSelect = {
  id: true,
  name: true,
  type: true,
  status: true,
  preferredContactMethod: true,
  notes: true,
  email: true,
  phone: true,
  addressLine1: true,
  city: true,
  state: true,
  zipCode: true,
  contactPerson: true,
  createdAt: true,
  updatedAt: true,
} satisfies Prisma.ClientSelect;

type ClientRow = Prisma.ClientGetPayload<{
  select: typeof clientSelect & typeof activeProjectsSelect;
}>;

/**
 * `activeProjects` is computed here rather than stored. In the Flutter app it
 * was a hand-entered integer that drifted from reality -- the seed claimed
 * c1=2 while only one project referenced c1.
 */
export function toDto(row: ClientRow): ClientDto {
  const activeProjects = row.projects.filter(
    (project) => deriveFromPhases(project.phases) !== 'done' && project.closedAt === null,
  ).length;

  return {
    id: row.id,
    name: row.name,
    activeProjects,
    type: row.type,
    status: row.status,
    preferredContactMethod: row.preferredContactMethod,
    notes: row.notes,
    email: row.email,
    phone: row.phone,
    addressLine1: row.addressLine1,
    city: row.city,
    state: row.state,
    zipCode: row.zipCode,
    contactPerson: row.contactPerson,
    createdAt: row.createdAt.toISOString(),
    updatedAt: row.updatedAt.toISOString(),
  };
}
