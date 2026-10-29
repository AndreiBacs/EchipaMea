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
import { ClientsService } from './clients.service';
import {
  ClientCreateRequest,
  ClientDto,
  ClientListQuery,
  ClientUpdateRequest,
  PagedClientsDto,
  clientCreateSchema,
  clientListQuerySchema,
  clientUpdateSchema,
} from './dto/client.dto';

@ApiTags('Clients')
@Controller('clients')
export class ClientsController {
  constructor(private readonly clients: ClientsService) {}

  @Get()
  @ApiOperation({
    operationId: 'listClients',
    summary: 'List clients',
    description:
      'Cursor-paginated. Returns `{ items, page }` rather than a bare array so the payload ' +
      'stays bounded as a tenant grows.',
  })
  @ApiQuery({ name: 'q', required: false, description: 'Case-insensitive name search.' })
  @ApiQuery({ name: 'status', required: false, enum: ['active', 'inactive', 'blocked'] })
  @ApiQuery({ name: 'type', required: false, enum: ['individual', 'company', 'publicInstitution'] })
  @ApiQuery({ name: 'limit', required: false, type: Number })
  @ApiQuery({ name: 'cursor', required: false })
  @ApiQuery({ name: 'withTotal', required: false, enum: ['true', 'false'] })
  @ApiOkResponse({ type: PagedClientsDto })
  list(
    @CurrentPrincipal() principal: Principal,
    @Query(zodBody(clientListQuerySchema)) query: ClientListQuery,
  ): Promise<Paged<ClientDto>> {
    return this.clients.list(principal.companyId, query);
  }

  @Post()
  @ApiOperation({
    operationId: 'createClient',
    summary: 'Create a client',
    description: '`activeProjects` is accepted for compatibility but ignored; it is derived.',
  })
  @ApiCreatedResponse({ type: ClientDto })
  create(
    @CurrentPrincipal() principal: Principal,
    @Body(zodBody(clientCreateSchema)) body: ClientCreateRequest,
  ): Promise<ClientDto> {
    return this.clients.create(principal.companyId, body);
  }

  @Get(':clientId')
  @ApiOperation({ operationId: 'getClient', summary: 'Get one client' })
  @ApiParam({ name: 'clientId', type: String })
  @ApiOkResponse({ type: ClientDto })
  get(
    @CurrentPrincipal() principal: Principal,
    @Param('clientId') clientId: string,
  ): Promise<ClientDto> {
    return this.clients.getById(principal.companyId, clientId);
  }

  @Patch(':clientId')
  @ApiOperation({
    operationId: 'updateClient',
    summary: 'Update a client',
    description: 'Genuinely partial: send only the fields that change.',
  })
  @ApiParam({ name: 'clientId', type: String })
  @ApiOkResponse({ type: ClientDto })
  update(
    @CurrentPrincipal() principal: Principal,
    @Param('clientId') clientId: string,
    @Body(zodBody(clientUpdateSchema)) body: ClientUpdateRequest,
  ): Promise<ClientDto> {
    return this.clients.update(principal.companyId, clientId, body);
  }

  @Delete(':clientId')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({
    operationId: 'deleteClient',
    summary: 'Soft-delete a client',
    description: 'Returns 409 CLIENT_HAS_PROJECTS while live projects still reference it.',
  })
  @ApiParam({ name: 'clientId', type: String })
  @ApiNoContentResponse({ description: 'Deleted.' })
  async remove(
    @CurrentPrincipal() principal: Principal,
    @Param('clientId') clientId: string,
  ): Promise<void> {
    await this.clients.remove(principal.companyId, clientId);
  }
}
