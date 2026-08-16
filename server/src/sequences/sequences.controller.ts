import { Body, Controller, Delete, Get, HttpCode, HttpStatus, Param, Put, Query } from '@nestjs/common';
import {
  ApiNoContentResponse,
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
import { SequencesService } from './sequences.service';
import {
  DailyWorkerSequenceDto,
  DayQuery,
  DaySequencesDto,
  SaveSequenceRequest,
  dayQuerySchema,
  saveSequenceSchema,
} from './dto/sequence.dto';

@ApiTags('Sequences')
@Controller()
export class SequencesController {
  constructor(private readonly sequences: SequencesService) {}

  /**
   * Bulk read for a whole day.
   *
   * Declared before the parameterised project routes so `/sequences` is not
   * shadowed, and exists so the dashboard does not issue one request per
   * employee per project.
   */
  @Get('sequences')
  @ApiOperation({
    operationId: 'listDaySequences',
    summary: 'Every worker sequence in the company for one day',
    description:
      'One request replaces the per-employee-per-project fan-out the foreman dashboard would ' +
      'otherwise perform. Includes a phaseId -> name map so callers need not refetch projects.',
  })
  @ApiQuery({ name: 'day', required: true, example: '2026-04-14' })
  @ApiOkResponse({ type: DaySequencesDto })
  listDay(
    @CurrentPrincipal() principal: Principal,
    @Query(zodBody(dayQuerySchema)) query: DayQuery,
  ): Promise<DaySequencesDto> {
    return this.sequences.getDay(principal.companyId, query.day);
  }

  @Roles('foreman', 'admin', 'worker')
  @Get('workers/:workerId/sequence')
  @ApiOperation({
    operationId: 'getWorkerDaySchedule',
    summary: 'One worker day across every project',
  })
  @ApiParam({ name: 'workerId', type: String })
  @ApiQuery({ name: 'day', required: true, example: '2026-04-14' })
  @ApiOkResponse({ type: DaySequencesDto })
  getForWorker(
    @CurrentPrincipal() principal: Principal,
    @Param('workerId') workerId: string,
    @Query(zodBody(dayQuerySchema)) query: DayQuery,
  ): Promise<DaySequencesDto> {
    return this.sequences.getForWorker(principal.companyId, workerId, query.day);
  }

  @Roles('foreman', 'admin', 'worker')
  @Get('projects/:projectId/workers/:workerId/sequence')
  @ApiOperation({
    operationId: 'getWorkerDailySequence',
    summary: 'A worker sequence for one project and day',
    description:
      'Never 404s for a missing manual order: it returns the computed suggestion with ' +
      '`isManual: false`. 404 means the project or worker does not exist. `suggestedPhaseIds` ' +
      'is always populated alongside the effective order.',
  })
  @ApiParam({ name: 'projectId', type: String })
  @ApiParam({ name: 'workerId', type: String })
  @ApiQuery({ name: 'day', required: true, example: '2026-04-14' })
  @ApiOkResponse({ type: DailyWorkerSequenceDto })
  getOne(
    @CurrentPrincipal() principal: Principal,
    @Param('projectId') projectId: string,
    @Param('workerId') workerId: string,
    @Query(zodBody(dayQuerySchema)) query: DayQuery,
  ): Promise<DailyWorkerSequenceDto> {
    return this.sequences.getOne(principal.companyId, projectId, workerId, query.day);
  }

  @Put('projects/:projectId/workers/:workerId/sequence')
  @ApiOperation({
    operationId: 'saveWorkerDailySequence',
    summary: 'Save a manual order for a day',
    description:
      'PUT because this genuinely replaces the whole ordering. Ids must belong to the project ' +
      'but need not match the suggestion -- a foreman may schedule a phase whose date window ' +
      'does not cover the day.',
  })
  @ApiParam({ name: 'projectId', type: String })
  @ApiParam({ name: 'workerId', type: String })
  @ApiQuery({ name: 'day', required: true, example: '2026-04-14' })
  @ApiOkResponse({ type: DailyWorkerSequenceDto })
  save(
    @CurrentPrincipal() principal: Principal,
    @Param('projectId') projectId: string,
    @Param('workerId') workerId: string,
    @Query(zodBody(dayQuerySchema)) query: DayQuery,
    @Body(zodBody(saveSequenceSchema)) body: SaveSequenceRequest,
  ): Promise<DailyWorkerSequenceDto> {
    return this.sequences.save(
      principal.companyId,
      projectId,
      workerId,
      query.day,
      body.orderedPhaseIds,
      principal.userId,
    );
  }

  @Delete('projects/:projectId/workers/:workerId/sequence')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({
    operationId: 'resetWorkerDailySequence',
    summary: 'Drop the manual order and fall back to the suggestion',
    description: 'Idempotent: 204 even when no override existed.',
  })
  @ApiParam({ name: 'projectId', type: String })
  @ApiParam({ name: 'workerId', type: String })
  @ApiQuery({ name: 'day', required: true, example: '2026-04-14' })
  @ApiNoContentResponse({ description: 'Reset.' })
  async reset(
    @CurrentPrincipal() principal: Principal,
    @Param('projectId') projectId: string,
    @Param('workerId') workerId: string,
    @Query(zodBody(dayQuerySchema)) query: DayQuery,
  ): Promise<void> {
    await this.sequences.reset(principal.companyId, projectId, workerId, query.day);
  }
}
