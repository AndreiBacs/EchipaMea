import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Patch,
  Post,
  Query,
} from '@nestjs/common';
import {
  ApiCreatedResponse,
  ApiNoContentResponse,
  ApiOkResponse,
  ApiOperation,
  ApiParam,
  ApiQuery,
  ApiTags,
} from '@nestjs/swagger';
import { CurrentPrincipal } from '../common/decorators/current-principal.decorator';
import { zodBody } from '../common/pipes/zod-validation.pipe';
import type { Paged } from '../common/dto/page.dto';
import type { Principal } from '../common/auth/principal';
import { EmployeesService } from './employees.service';
import {
  EmployeeCreateRequest,
  EmployeeDto,
  EmployeeListQuery,
  EmployeeUpdateRequest,
  PagedEmployeesDto,
  employeeCreateSchema,
  employeeListQuerySchema,
  employeeUpdateSchema,
} from './dto/employee.dto';

@ApiTags('Employees')
@Controller('employees')
export class EmployeesController {
  constructor(private readonly employees: EmployeesService) {}

  @Get()
  @ApiOperation({ operationId: 'listEmployees', summary: 'List employees' })
  @ApiQuery({ name: 'q', required: false, description: 'Case-insensitive name search.' })
  @ApiQuery({ name: 'role', required: false })
  @ApiQuery({ name: 'active', required: false, enum: ['true', 'false'] })
  @ApiQuery({ name: 'limit', required: false, type: Number })
  @ApiQuery({ name: 'cursor', required: false })
  @ApiQuery({ name: 'withTotal', required: false, enum: ['true', 'false'] })
  @ApiOkResponse({ type: PagedEmployeesDto })
  list(
    @CurrentPrincipal() principal: Principal,
    @Query(zodBody(employeeListQuerySchema)) query: EmployeeListQuery,
  ): Promise<Paged<EmployeeDto>> {
    return this.employees.list(principal.companyId, query);
  }

  @Post()
  @ApiOperation({
    operationId: 'createEmployee',
    summary: 'Create an employee',
    description:
      '`workingDays` uses ISO-8601 weekdays (1=Mon .. 7=Sun) and, with the work hours, gates ' +
      'whether the worker device streams location telemetry.',
  })
  @ApiCreatedResponse({ type: EmployeeDto })
  create(
    @CurrentPrincipal() principal: Principal,
    @Body(zodBody(employeeCreateSchema)) body: EmployeeCreateRequest,
  ): Promise<EmployeeDto> {
    return this.employees.create(principal.companyId, body);
  }

  @Get(':employeeId')
  @ApiOperation({ operationId: 'getEmployee', summary: 'Get one employee' })
  @ApiParam({ name: 'employeeId', type: String })
  @ApiOkResponse({ type: EmployeeDto })
  get(
    @CurrentPrincipal() principal: Principal,
    @Param('employeeId') employeeId: string,
  ): Promise<EmployeeDto> {
    return this.employees.getById(principal.companyId, employeeId);
  }

  @Patch(':employeeId')
  @ApiOperation({
    operationId: 'updateEmployee',
    summary: 'Update an employee',
    description:
      'Partial. `latitude`/`longitude` accept an explicit null to clear. Setting ' +
      '`isActive: false` also revokes the worker active sessions.',
  })
  @ApiParam({ name: 'employeeId', type: String })
  @ApiOkResponse({ type: EmployeeDto })
  update(
    @CurrentPrincipal() principal: Principal,
    @Param('employeeId') employeeId: string,
    @Body(zodBody(employeeUpdateSchema)) body: EmployeeUpdateRequest,
  ): Promise<EmployeeDto> {
    return this.employees.update(principal.companyId, employeeId, body);
  }

  @Delete(':employeeId')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({
    operationId: 'deleteEmployee',
    summary: 'Soft-delete an employee',
    description:
      'The row is retained so assignments and report history stay intact. Active sessions ' +
      'are revoked immediately.',
  })
  @ApiParam({ name: 'employeeId', type: String })
  @ApiNoContentResponse({ description: 'Deleted.' })
  async remove(
    @CurrentPrincipal() principal: Principal,
    @Param('employeeId') employeeId: string,
  ): Promise<void> {
    await this.employees.remove(principal.companyId, employeeId);
  }
}
