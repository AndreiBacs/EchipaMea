import { Body, Controller, Get, Patch } from '@nestjs/common';
import { ApiOkResponse, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentForeman } from '../common/decorators/current-principal.decorator';
import { zodBody } from '../common/pipes/zod-validation.pipe';
import type { ForemanPrincipal } from '../common/auth/principal';
import { CompanyService } from './company.service';
import {
  CompanyDto,
  CompanyUpdateRequest,
  ForemanProfileDto,
  ProfileUpdateRequest,
  companyUpdateSchema,
  profileUpdateSchema,
} from './dto/company.dto';

@ApiTags('Company')
@Controller()
export class CompanyController {
  constructor(private readonly company: CompanyService) {}

  @Get('company')
  @ApiOperation({
    operationId: 'getCompany',
    summary: "The signed-in foreman's company",
    description:
      'Replaces the company half of the SharedPreferences profile blob. Note this is a shared ' +
      'record: two foremen see and edit the same one, which the on-device version could not do.',
  })
  @ApiOkResponse({ type: CompanyDto })
  get(@CurrentForeman() principal: ForemanPrincipal): Promise<CompanyDto> {
    return this.company.get(principal.companyId);
  }

  @Patch('company')
  @ApiOperation({
    operationId: 'updateCompany',
    summary: 'Update company details',
    description:
      'Genuinely partial: omitted fields are left alone. The company id comes from the token, ' +
      'so there is no way to name a different one.',
  })
  @ApiOkResponse({ type: CompanyDto })
  update(
    @CurrentForeman() principal: ForemanPrincipal,
    @Body(zodBody(companyUpdateSchema)) body: CompanyUpdateRequest,
  ): Promise<CompanyDto> {
    return this.company.update(principal.companyId, body);
  }

  @Get('me/profile')
  @ApiOperation({
    operationId: 'getForemanProfile',
    summary: "The signed-in foreman's own profile",
    description:
      'The settings-screen view: name, phone, job title. `GET /auth/me` answers a different ' +
      'question -- who this token is, for routing and guards.',
  })
  @ApiOkResponse({ type: ForemanProfileDto })
  profile(@CurrentForeman() principal: ForemanPrincipal): Promise<ForemanProfileDto> {
    return this.company.profile(principal);
  }

  @Patch('me/profile')
  @ApiOperation({
    operationId: 'updateForemanProfile',
    summary: 'Update your own name, phone or job title',
    description: 'Role, email and tenant are not editable here.',
  })
  @ApiOkResponse({ type: ForemanProfileDto })
  updateProfile(
    @CurrentForeman() principal: ForemanPrincipal,
    @Body(zodBody(profileUpdateSchema)) body: ProfileUpdateRequest,
  ): Promise<ForemanProfileDto> {
    return this.company.updateProfile(principal, body);
  }
}
