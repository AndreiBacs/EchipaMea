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
} from '@nestjs/common';
import {
  ApiCreatedResponse,
  ApiNoContentResponse,
  ApiOkResponse,
  ApiOperation,
  ApiParam,
  ApiTags,
} from '@nestjs/swagger';
import { CurrentForeman, CurrentPrincipal } from '../common/decorators/current-principal.decorator';
import { Roles } from '../common/decorators/roles.decorator';
import { zodBody } from '../common/pipes/zod-validation.pipe';
import type { ForemanPrincipal, Principal } from '../common/auth/principal';
import { ProjectDto, ProjectPhaseDto } from '../projects/dto/project.dto';
import { PhasesService } from './phases.service';
import {
  PhaseCreateRequest,
  PhaseReportSummaryDto,
  PhaseReorderRequest,
  PhaseReviewRequest,
  PhaseSubmitRequest,
  PhaseUpdateRequest,
  phaseCreateSchema,
  phaseReorderSchema,
  phaseReviewSchema,
  phaseSubmitSchema,
  phaseUpdateSchema,
} from './dto/phase.dto';

@ApiTags('Phases')
@Controller('projects/:projectId/phases')
export class PhasesController {
  constructor(private readonly phases: PhasesService) {}

  @Roles('foreman', 'admin', 'worker')
  @Get()
  @ApiOperation({
    operationId: 'listProjectPhases',
    summary: 'List the phases of a project',
    description: 'Ordered by the explicit sortIndex. Absent from the draft spec.',
  })
  @ApiParam({ name: 'projectId', type: String })
  @ApiOkResponse({ type: [ProjectPhaseDto] })
  list(
    @CurrentPrincipal() principal: Principal,
    @Param('projectId') projectId: string,
  ): Promise<ProjectPhaseDto[]> {
    return this.phases.list(principal.companyId, projectId);
  }

  @Post()
  @ApiOperation({
    operationId: 'createProjectPhase',
    summary: 'Add a phase',
    description: 'Appended at the end of the ordering.',
  })
  @ApiParam({ name: 'projectId', type: String })
  @ApiCreatedResponse({ type: ProjectPhaseDto })
  create(
    @CurrentPrincipal() principal: Principal,
    @Param('projectId') projectId: string,
    @Body(zodBody(phaseCreateSchema)) body: PhaseCreateRequest,
  ): Promise<ProjectPhaseDto> {
    return this.phases.create(principal.companyId, projectId, body);
  }

  @Post('reorder')
  @ApiOperation({
    operationId: 'reorderProjectPhases',
    summary: 'Reorder phases',
    description: 'Requires the full permutation: every phase id exactly once.',
  })
  @ApiParam({ name: 'projectId', type: String })
  @ApiOkResponse({ type: [ProjectPhaseDto] })
  reorder(
    @CurrentPrincipal() principal: Principal,
    @Param('projectId') projectId: string,
    @Body(zodBody(phaseReorderSchema)) body: PhaseReorderRequest,
  ): Promise<ProjectPhaseDto[]> {
    return this.phases.reorder(principal.companyId, projectId, body.phaseIds);
  }

  @Roles('foreman', 'admin', 'worker')
  @Get(':phaseId')
  @ApiOperation({ operationId: 'getProjectPhase', summary: 'Get one phase' })
  @ApiParam({ name: 'projectId', type: String })
  @ApiParam({ name: 'phaseId', type: String })
  @ApiOkResponse({ type: ProjectPhaseDto })
  get(
    @CurrentPrincipal() principal: Principal,
    @Param('projectId') projectId: string,
    @Param('phaseId') phaseId: string,
  ): Promise<ProjectPhaseDto> {
    return this.phases.getById(principal.companyId, projectId, phaseId);
  }

  @Patch(':phaseId')
  @ApiOperation({
    operationId: 'updateProjectPhase',
    summary: 'Update a phase',
    description:
      'Partial. A present `workInstructions` replaces the whole list, matching how the ' +
      'foreman editor submits it.',
  })
  @ApiParam({ name: 'projectId', type: String })
  @ApiParam({ name: 'phaseId', type: String })
  @ApiOkResponse({ type: ProjectPhaseDto })
  update(
    @CurrentPrincipal() principal: Principal,
    @Param('projectId') projectId: string,
    @Param('phaseId') phaseId: string,
    @Body(zodBody(phaseUpdateSchema)) body: PhaseUpdateRequest,
  ): Promise<ProjectPhaseDto> {
    return this.phases.update(principal.companyId, projectId, phaseId, body);
  }

  @Delete(':phaseId')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({
    operationId: 'deleteProjectPhase',
    summary: 'Remove a phase',
    description: 'Also prunes the phase from any saved manual day orders.',
  })
  @ApiParam({ name: 'projectId', type: String })
  @ApiParam({ name: 'phaseId', type: String })
  @ApiNoContentResponse({ description: 'Deleted.' })
  async remove(
    @CurrentPrincipal() principal: Principal,
    @Param('projectId') projectId: string,
    @Param('phaseId') phaseId: string,
  ): Promise<void> {
    await this.phases.remove(principal.companyId, projectId, phaseId);
  }

  @Roles('foreman', 'admin', 'worker')
  @Post(':phaseId/start')
  @ApiOperation({
    operationId: 'startProjectPhase',
    summary: 'Move a phase from notStarted to inProgress',
  })
  @ApiParam({ name: 'projectId', type: String })
  @ApiParam({ name: 'phaseId', type: String })
  @ApiOkResponse({ type: ProjectPhaseDto })
  start(
    @CurrentPrincipal() principal: Principal,
    @Param('projectId') projectId: string,
    @Param('phaseId') phaseId: string,
  ): Promise<ProjectPhaseDto> {
    return this.phases.start(principal.companyId, projectId, phaseId);
  }

  @Roles('foreman', 'admin', 'worker')
  @Post(':phaseId/submit')
  @ApiOperation({
    operationId: 'submitProjectPhase',
    summary: 'Submit a phase for review',
    description:
      'With a worker token the submitting employee is taken from the JWT and any `employeeId` ' +
      'in the body is ignored. Returns 409 PHASE_INVALID_TRANSITION unless the phase is ' +
      'notStarted or inProgress.',
  })
  @ApiParam({ name: 'projectId', type: String })
  @ApiParam({ name: 'phaseId', type: String })
  @ApiOkResponse({ type: ProjectPhaseDto })
  submit(
    @CurrentPrincipal() principal: Principal,
    @Param('projectId') projectId: string,
    @Param('phaseId') phaseId: string,
    @Body(zodBody(phaseSubmitSchema)) body: PhaseSubmitRequest,
  ): Promise<ProjectPhaseDto> {
    return this.phases.submit(principal.companyId, projectId, phaseId, principal, body.employeeId);
  }

  @Post(':phaseId/review')
  @ApiOperation({
    operationId: 'reviewProjectPhase',
    summary: 'Approve or reject a phase',
    description:
      'Foreman only. The reviewer is taken from the JWT. Rejection returns the phase to ' +
      'inProgress. Returns the whole project, because approving the last phase also changes ' +
      'the derived project status.',
  })
  @ApiParam({ name: 'projectId', type: String })
  @ApiParam({ name: 'phaseId', type: String })
  @ApiOkResponse({ type: ProjectDto })
  review(
    @CurrentForeman() principal: ForemanPrincipal,
    @Param('projectId') projectId: string,
    @Param('phaseId') phaseId: string,
    @Body(zodBody(phaseReviewSchema)) body: PhaseReviewRequest,
  ): Promise<ProjectDto> {
    return this.phases.review(principal.companyId, projectId, phaseId, principal, body);
  }

  @Get(':phaseId/reports')
  @ApiOperation({
    operationId: 'listPhaseReports',
    summary: 'Worker reports submitted against a phase',
  })
  @ApiParam({ name: 'projectId', type: String })
  @ApiParam({ name: 'phaseId', type: String })
  @ApiOkResponse({ type: [PhaseReportSummaryDto] })
  listReports(
    @CurrentPrincipal() principal: Principal,
    @Param('projectId') projectId: string,
    @Param('phaseId') phaseId: string,
  ): Promise<PhaseReportSummaryDto[]> {
    return this.phases.listReports(principal.companyId, projectId, phaseId);
  }
}
