import { Module } from '@nestjs/common';
import { ReportsModule } from '../reports/reports.module';
import { ForemanNotificationsGateway } from './foreman-notifications.gateway';
import { E2eHooksController } from './e2e-hooks.controller';
import { RealtimeController } from './realtime.controller';
import { RealtimeCoreModule } from './realtime-core.module';
import { RealtimeTicketService } from './realtime-ticket.service';
import { WorkerTelemetryGateway } from './worker-telemetry.gateway';
import { WsAuthService } from './ws-auth.service';
import { WsSessionService } from './ws-session.service';

/**
 * Gateways and handshake plumbing.
 *
 * The registry itself lives in `RealtimeCoreModule`, which this imports and so
 * do the publishers. Keeping it separate is what lets `ReportsModule` fan out to
 * foremen while this module depends on `ReportsModule` to handle inbound frames.
 */
@Module({
  imports: [RealtimeCoreModule, ReportsModule],
  controllers: [RealtimeController, E2eHooksController],
  providers: [
    RealtimeTicketService,
    WsAuthService,
    WsSessionService,
    WorkerTelemetryGateway,
    ForemanNotificationsGateway,
  ],
  exports: [RealtimeTicketService],
})
export class RealtimeModule {}
