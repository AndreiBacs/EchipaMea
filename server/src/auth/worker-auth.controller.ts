import { Body, Controller, HttpCode, HttpStatus, Param, Post, Req } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { ApiOkResponse, ApiOperation, ApiParam, ApiTags } from '@nestjs/swagger';
import type { Request } from 'express';
import { CurrentForeman } from '../common/decorators/current-principal.decorator';
import { Public } from '../common/decorators/public.decorator';
import { zodBody } from '../common/pipes/zod-validation.pipe';
import type { ForemanPrincipal } from '../common/auth/principal';
import { metaOf } from './auth.controller';
import { WorkerSessionResponseDto } from './dto/auth.dto';
import {
  RedeemTicketRequest,
  WorkerLoginTicketDto,
  redeemTicketSchema,
} from './dto/worker-ticket.dto';
import { WorkerTicketService } from './worker-ticket.service';

@ApiTags('Auth')
@Controller()
export class WorkerAuthController {
  constructor(private readonly tickets: WorkerTicketService) {}

  @Post('employees/:employeeId/login-ticket')
  @ApiOperation({
    operationId: 'issueWorkerLoginTicket',
    summary: 'Mint a QR login ticket for an employee',
    description:
      'Foreman only. Render the returned `qrPayload` verbatim into the QR code. The ticket ' +
      'is a single-use opaque secret and is stored only as a hash.',
  })
  @ApiParam({ name: 'employeeId', type: String })
  @ApiOkResponse({ type: WorkerLoginTicketDto })
  issueTicket(
    @CurrentForeman() principal: ForemanPrincipal,
    @Param('employeeId') employeeId: string,
  ): Promise<WorkerLoginTicketDto> {
    return this.tickets.issue(principal, employeeId);
  }

  @Public()
  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  @Post('worker/login-tickets/redeem')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    operationId: 'redeemWorkerLoginTicket',
    summary: 'Exchange a scanned QR ticket for a worker session',
    description:
      'Public. Accepts either a bare `ticketId` or the raw scanned `payload` (JSON, or a URL ' +
      'carrying it in `?payload=` plain or base64). Returns 404 for an unknown code, ' +
      '409 TICKET_ALREADY_REDEEMED for a reused one, 410 TICKET_EXPIRED for a stale one.',
  })
  @ApiOkResponse({ type: WorkerSessionResponseDto })
  redeemTicket(
    @Body(zodBody(redeemTicketSchema)) body: RedeemTicketRequest,
    @Req() request: Request,
  ): Promise<WorkerSessionResponseDto> {
    return this.tickets.redeem({ ticketId: body.ticketId, payload: body.payload }, metaOf(request));
  }
}
