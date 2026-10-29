import { Injectable } from '@nestjs/common';
import { AppException } from '../common/errors/app-exception';
import { PrismaService } from '../common/prisma/prisma.service';
import type { ForemanPrincipal } from '../common/auth/principal';
import type {
  CompanyDto,
  CompanyUpdateRequest,
  ForemanProfileDto,
  ProfileUpdateRequest,
} from './dto/company.dto';

type CompanyRow = {
  id: string;
  name: string;
  addressLine1: string;
  city: string;
  state: string;
  zipCode: string;
  iban: string;
  cui: string;
  vatNumber: string;
  regCom: string;
};

@Injectable()
export class CompanyService {
  constructor(private readonly prisma: PrismaService) {}

  async get(companyId: string): Promise<CompanyDto> {
    const company = await this.prisma.company.findUnique({ where: { id: companyId } });
    if (!company) throw AppException.notFound('Company', companyId);
    return toCompanyDto(company);
  }

  /**
   * Partial update, and genuinely partial.
   *
   * The draft spec's PATCH bodies required every field, which is full-replace
   * behind a PATCH verb: a client that knew about eight fields would silently
   * blank a ninth it had never heard of.
   */
  async update(companyId: string, input: CompanyUpdateRequest): Promise<CompanyDto> {
    const company = await this.prisma.company.update({
      where: { id: companyId },
      data: input,
    });
    return toCompanyDto(company);
  }

  /**
   * The signed-in foreman's own editable profile.
   *
   * Distinct from `GET /auth/me`, which answers "who is this token" for routing
   * and guards. This one is the settings screen: the fields a person edits about
   * themselves, and never their role or tenant.
   */
  async profile(principal: ForemanPrincipal): Promise<ForemanProfileDto> {
    const user = await this.prisma.user.findFirst({
      where: { id: principal.userId, companyId: principal.companyId, deletedAt: null },
      include: { company: { select: { id: true, name: true } } },
    });
    if (!user) throw AppException.notFound('User', principal.userId);

    return {
      userId: user.id,
      email: user.email,
      role: user.role,
      fullName: user.fullName,
      phone: user.phone,
      jobTitle: user.jobTitle,
      companyId: user.company.id,
      companyName: user.company.name,
    };
  }

  async updateProfile(
    principal: ForemanPrincipal,
    input: ProfileUpdateRequest,
  ): Promise<ForemanProfileDto> {
    // Scoped by company as well as id: `id` alone would be a cross-tenant write
    // if a user id ever leaked between companies.
    await this.prisma.user.update({
      where: { id_companyId: { id: principal.userId, companyId: principal.companyId } },
      data: input,
    });
    return this.profile(principal);
  }
}

function toCompanyDto(company: CompanyRow): CompanyDto {
  return {
    id: company.id,
    name: company.name,
    addressLine1: company.addressLine1,
    city: company.city,
    state: company.state,
    zipCode: company.zipCode,
    // Derived, not stored -- the same rule the rest of the model follows.
    addressLine: [company.addressLine1, company.city, company.state, company.zipCode]
      .map((part) => part.trim())
      .filter(Boolean)
      .join(', '),
    iban: company.iban,
    cui: company.cui,
    vatNumber: company.vatNumber,
    regCom: company.regCom,
  };
}
