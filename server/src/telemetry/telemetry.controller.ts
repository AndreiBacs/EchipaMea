import { Controller, Get, Query } from '@nestjs/common';
import { ApiOkResponse, ApiOperation, ApiQuery, ApiTags } from '@nestjs/swagger';
import { CurrentPrincipal } from '../common/decorators/current-principal.decorator';
import { zodBody } from '../common/pipes/zod-validation.pipe';
import type { Principal } from '../common/auth/principal';
import { TelemetryService } from './telemetry.service';
import {
  ArrivalListQuery,
  ArrivalsDto,
  LatestLocationsDto,
  LocationTrailDto,
  TelemetryWindowQuery,
  arrivalListQuerySchema,
  telemetryWindowSchema,
} from './dto/telemetry.dto';

/**
 * Reading the telemetry the worker app writes.
 *
 * Foreman-only, by the guard's fail-closed default. A worker may write its own
 * position and must not be able to read anyone else's -- location history is
 * the most sensitive data in this product.
 */
@ApiTags('Telemetry')
@Controller()
export class TelemetryController {
  constructor(private readonly telemetry: TelemetryService) {}

  @Get('telemetry/locations')
  @ApiOperation({
    operationId: 'listLocationSamples',
    summary: 'Location trail for a time window',
    description:
      'Defaults to the last 24 hours when no window is given, rather than scanning the whole ' +
      'retention period. Newest first.',
  })
  @ApiQuery({ name: 'employeeId', required: false })
  @ApiQuery({ name: 'from', required: false, type: String })
  @ApiQuery({ name: 'to', required: false, type: String })
  @ApiQuery({ name: 'limit', required: false, type: Number })
  @ApiOkResponse({ type: LocationTrailDto })
  trail(
    @CurrentPrincipal() principal: Principal,
    @Query(zodBody(telemetryWindowSchema)) query: TelemetryWindowQuery,
  ): Promise<LocationTrailDto> {
    return this.telemetry.trail(principal.companyId, query);
  }

  @Get('telemetry/latest')
  @ApiOperation({
    operationId: 'listLatestLocations',
    summary: 'Where each employee was last seen',
    description:
      'One row per employee, most recent first by age. `ageSeconds` is usually large and that ' +
      'is normal: the app samples every 30 minutes and only inside the working window.',
  })
  @ApiOkResponse({ type: LatestLocationsDto })
  latest(@CurrentPrincipal() principal: Principal): Promise<LatestLocationsDto> {
    return this.telemetry.latest(principal.companyId);
  }

  @Get('arrivals')
  @ApiOperation({
    operationId: 'listArrivals',
    summary: 'Worker arrivals on site',
    description: 'Filterable by project, employee and calendar day. Newest first.',
  })
  @ApiQuery({ name: 'projectId', required: false })
  @ApiQuery({ name: 'employeeId', required: false })
  @ApiQuery({ name: 'day', required: false, example: '2026-08-16' })
  @ApiQuery({ name: 'limit', required: false, type: Number })
  @ApiOkResponse({ type: ArrivalsDto })
  arrivals(
    @CurrentPrincipal() principal: Principal,
    @Query(zodBody(arrivalListQuerySchema)) query: ArrivalListQuery,
  ): Promise<ArrivalsDto> {
    return this.telemetry.arrivals(principal.companyId, query);
  }
}
