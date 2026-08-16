import { Body, Controller, Get, HttpCode, HttpStatus, Param, Post, Query } from '@nestjs/common';
import {
  ApiCreatedResponse,
  ApiOkResponse,
  ApiOperation,
  ApiParam,
  ApiQuery,
  ApiTags,
} from '@nestjs/swagger';
import { CurrentPrincipal } from '../common/decorators/current-principal.decorator';
import { Roles } from '../common/decorators/roles.decorator';
import { zodBody } from '../common/pipes/zod-validation.pipe';
import type { Principal } from '../common/auth/principal';
import { ProjectDto } from '../projects/dto/project.dto';
import { WorkerService } from './worker.service';
import {
  ArrivalCreateRequest,
  LocationBatchRequest,
  LocationBatchResultDto,
  WorkerArrivalDto,
  WorkerProfileDto,
  WorkerProjectsDto,
  WorkerProjectsQuery,
  arrivalCreateSchema,
  locationBatchSchema,
  workerProjectsQuerySchema,
} from './dto/worker.dto';

/**
 * Everything a worker session may read or write about itself.
 *
 * `@Roles('worker')` on the class, not the default: `RolesGuard` is fail-closed
 * to foreman/admin, and these are the opposite -- a foreman token has no
 * employee identity, so there is nothing here for it to mean.
 *
 * None of these carry an `@AllowAnonymousWorker()` escape hatch. The transition
 * flags exist for endpoints the shipped app already calls; nothing calls these
 * yet, so they start out requiring a real worker token and stay that way.
 */
@ApiTags('Worker')
@Roles('worker')
@Controller('worker')
export class WorkerController {
  constructor(private readonly worker: WorkerService) {}

  @Get('me')
  @ApiOperation({
    operationId: 'getWorkerProfile',
    summary: "The signed-in worker's own profile",
    description:
      'Includes the working-days and working-hours window that gates location telemetry. The ' +
      'app reads those from the foreman roster today, which means every worker phone holds ' +
      "the whole company's employee list.",
  })
  @ApiOkResponse({ type: WorkerProfileDto })
  me(@CurrentPrincipal() principal: Principal): Promise<WorkerProfileDto> {
    return this.worker.profile(principal);
  }

  @Get('projects')
  @ApiOperation({
    operationId: 'listWorkerProjects',
    summary: 'Projects assigned to the signed-in worker',
    description:
      'Assigned at project level or to any of its live phases. Finished projects are omitted ' +
      'unless `includeDone=true`, and the list is ordered inProgress, planned, done, then by ' +
      'name -- matching the app. Returned whole rather than cursor-paginated: both the filter ' +
      'and the sort key are derived from phases, so no SQL cursor can express the boundary.',
  })
  @ApiQuery({ name: 'includeDone', required: false, type: Boolean })
  @ApiQuery({ name: 'limit', required: false, type: Number })
  @ApiOkResponse({ type: WorkerProjectsDto })
  projects(
    @CurrentPrincipal() principal: Principal,
    @Query(zodBody(workerProjectsQuerySchema)) query: WorkerProjectsQuery,
  ): Promise<WorkerProjectsDto> {
    return this.worker.projects(principal, query);
  }

  @Get('projects/:projectId')
  @ApiOperation({
    operationId: 'getWorkerProject',
    summary: 'One assigned project, with its phases and work instructions',
    description:
      'Answers 404 for a project that exists but is not assigned to this worker, so the ' +
      'endpoint cannot be used to enumerate the company.',
  })
  @ApiParam({ name: 'projectId' })
  @ApiOkResponse({ type: ProjectDto })
  project(
    @CurrentPrincipal() principal: Principal,
    @Param('projectId') projectId: string,
  ): Promise<ProjectDto> {
    return this.worker.project(principal, projectId);
  }

  @Post('arrivals')
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({
    operationId: 'announceWorkerArrival',
    summary: 'Announce arrival on site',
    description:
      'Notifies every foreman in the company, by stored notification and by socket. Repeat ' +
      'taps within 15 minutes return the first arrival with `duplicate: true` rather than ' +
      'putting a second row in front of the foreman.',
  })
  @ApiCreatedResponse({ type: WorkerArrivalDto })
  announceArrival(
    @CurrentPrincipal() principal: Principal,
    @Body(zodBody(arrivalCreateSchema)) body: ArrivalCreateRequest,
  ): Promise<WorkerArrivalDto> {
    return this.worker.announceArrival(principal, body);
  }

  @Post('locations')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    operationId: 'recordWorkerLocations',
    summary: 'Batch location upload (offline outbox flush)',
    description:
      'The catch-up path for fixes captured while the telemetry socket was down. Safe to ' +
      'retry: samples whose `capturedAt` is already stored are counted as duplicates rather ' +
      'than written twice. Batches over 500 samples are rejected, not truncated.',
  })
  @ApiOkResponse({ type: LocationBatchResultDto })
  recordLocations(
    @CurrentPrincipal() principal: Principal,
    @Body(zodBody(locationBatchSchema)) body: LocationBatchRequest,
  ): Promise<LocationBatchResultDto> {
    return this.worker.recordLocations(principal, body);
  }
}
