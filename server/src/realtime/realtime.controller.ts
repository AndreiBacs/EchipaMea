import { Controller, HttpCode, HttpStatus, Post } from '@nestjs/common';
import { ApiCreatedResponse, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentPrincipal } from '../common/decorators/current-principal.decorator';
import { Roles } from '../common/decorators/roles.decorator';
import type { Principal } from '../common/auth/principal';
import { RealtimeTicketService, type RealtimeTicketDto } from './realtime-ticket.service';

@ApiTags('Realtime')
@Controller('realtime')
export class RealtimeController {
  constructor(private readonly tickets: RealtimeTicketService) {}

  @Roles('worker', 'foreman', 'admin')
  @Post('tickets')
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({
    operationId: 'createRealtimeTicket',
    summary: 'Mint a single-use ticket for a WebSocket handshake',
    description:
      'Returns a short-lived ticket to pass as `?ticket=` when opening a channel, plus the ' +
      'channel paths. Single-use: fetch a new one per connection attempt, including reconnects. ' +
      'Exists because Dart cannot set headers on a WebSocket from Flutter web.',
  })
  @ApiCreatedResponse({ description: 'Ticket minted.' })
  async create(@CurrentPrincipal() principal: Principal): Promise<RealtimeTicketDto> {
    return this.tickets.issue(principal);
  }
}
