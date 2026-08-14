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
import { ProjectsService } from './projects.service';
import {
  PagedProjectsDto,
  ProjectCreateRequest,
  ProjectDto,
  ProjectListQuery,
  ProjectUpdateRequest,
  projectCreateSchema,
  projectListQuerySchema,
  projectUpdateSchema,
} from './dto/project.dto';

@ApiTags('Projects')
@Controller('projects')
export class ProjectsController {
  constructor(private readonly projects: ProjectsService) {}

  @Get()
  @ApiOperation({
    operationId: 'listProjects',
    summary: 'List projects',
    description:
      'Note: `status` is a derived value, so it is applied after the database query. A page ' +
      'filtered by status may therefore contain fewer than `limit` items while more pages remain.',
  })
  @ApiQuery({ name: 'q', required: false })
  @ApiQuery({ name: 'clientId', required: false })
  @ApiQuery({ name: 'status', required: false, enum: ['planned', 'inProgress', 'done'] })
  @ApiQuery({ name: 'assignedEmployeeId', required: false })
  @ApiQuery({ name: 'limit', required: false, type: Number })
  @ApiQuery({ name: 'cursor', required: false })
  @ApiOkResponse({ type: PagedProjectsDto })
  list(
    @CurrentPrincipal() principal: Principal,
    @Query(zodBody(projectListQuerySchema)) query: ProjectListQuery,
  ): Promise<Paged<ProjectDto>> {
    return this.projects.list(principal.companyId, query);
  }

  @Post()
  @ApiOperation({
    operationId: 'createProject',
    summary: 'Create a project',
    description:
      'Phases may be supplied inline using the *create* shape (no id or status required). ' +
      '`status` and `workers` are accepted for compatibility but ignored -- both are derived.',
  })
  @ApiCreatedResponse({ type: ProjectDto })
  create(
    @CurrentPrincipal() principal: Principal,
    @Body(zodBody(projectCreateSchema)) body: ProjectCreateRequest,
  ): Promise<ProjectDto> {
    return this.projects.create(principal.companyId, body);
  }

  @Get(':projectId')
  @ApiOperation({ operationId: 'getProject', summary: 'Get one project' })
  @ApiParam({ name: 'projectId', type: String })
  @ApiOkResponse({ type: ProjectDto })
  get(
    @CurrentPrincipal() principal: Principal,
    @Param('projectId') projectId: string,
  ): Promise<ProjectDto> {
    return this.projects.getById(principal.companyId, projectId);
  }

  @Patch(':projectId')
  @ApiOperation({
    operationId: 'updateProject',
    summary: 'Update a project',
    description:
      'Partial. An omitted `assignedEmployeeIds` leaves assignments untouched; a present one ' +
      'replaces the whole set. Explicit null clears latitude/longitude.',
  })
  @ApiParam({ name: 'projectId', type: String })
  @ApiOkResponse({ type: ProjectDto })
  update(
    @CurrentPrincipal() principal: Principal,
    @Param('projectId') projectId: string,
    @Body(zodBody(projectUpdateSchema)) body: ProjectUpdateRequest,
  ): Promise<ProjectDto> {
    return this.projects.update(principal.companyId, projectId, body);
  }

  @Post(':projectId/done')
  @ApiOperation({
    operationId: 'markProjectDone',
    summary: 'Mark a project done',
    description:
      'Sets a `closedAt` override. Phase statuses are left untouched, so reopening restores ' +
      'the derived status rather than leaving a stale value.',
  })
  @ApiParam({ name: 'projectId', type: String })
  @ApiOkResponse({ type: ProjectDto })
  markDone(
    @CurrentPrincipal() principal: Principal,
    @Param('projectId') projectId: string,
  ): Promise<ProjectDto> {
    return this.projects.markDone(principal.companyId, projectId);
  }

  @Post(':projectId/reopen')
  @ApiOperation({
    operationId: 'reopenProject',
    summary: 'Clear the done override',
  })
  @ApiParam({ name: 'projectId', type: String })
  @ApiOkResponse({ type: ProjectDto })
  reopen(
    @CurrentPrincipal() principal: Principal,
    @Param('projectId') projectId: string,
  ): Promise<ProjectDto> {
    return this.projects.reopen(principal.companyId, projectId);
  }

  @Delete(':projectId')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ operationId: 'deleteProject', summary: 'Soft-delete a project' })
  @ApiParam({ name: 'projectId', type: String })
  @ApiNoContentResponse({ description: 'Deleted.' })
  async remove(
    @CurrentPrincipal() principal: Principal,
    @Param('projectId') projectId: string,
  ): Promise<void> {
    await this.projects.remove(principal.companyId, projectId);
  }
}
