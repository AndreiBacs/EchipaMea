import { Logger } from '@nestjs/common';
import {
  ConnectedSocket,
  MessageBody,
  OnGatewayConnection,
  OnGatewayDisconnect,
  SubscribeMessage,
  WebSocketGateway,
} from '@nestjs/websockets';
import type { IncomingMessage } from 'node:http';
import type { WebSocket } from 'ws';
import { ErrorCode } from '../common/errors/error-codes';
import { isForeman } from '../common/auth/principal';
import { WorkerReportsService } from '../reports/worker-reports.service';
import { ConnectionRegistryService, foremenRoom } from './connection-registry.service';
import { FrameType, ackFrame, errorFrame, workerReportSubmittedFrameSchema } from './frames';
import { WS_PATHS } from './realtime-ticket.service';
import { WsSessionService } from './ws-session.service';

/**
 * `/ws/foreman-notifications` -- asymmetric by role.
 *
 * Foremen join their company room and are receive-only. Workers join no room and
 * may send exactly one frame type: the one-shot `worker_report_submitted` the
 * app publishes right after a successful upload (connect, write, close, all in
 * a few milliseconds).
 *
 * A foreman that sends anything gets an `error` frame and keeps its connection.
 * Closing would be worse than useless: `foreman_notifications_coordinator.dart`
 * listens with `cancelOnError: true` and has no reconnect, so one stray frame
 * would end notifications until the app is restarted.
 */
@WebSocketGateway({ path: WS_PATHS.foremanNotifications, maxPayload: 32 * 1024 })
export class ForemanNotificationsGateway implements OnGatewayConnection, OnGatewayDisconnect {
  private readonly logger = new Logger(ForemanNotificationsGateway.name);

  constructor(
    private readonly sessions: WsSessionService,
    private readonly registry: ConnectionRegistryService,
    private readonly reports: WorkerReportsService,
  ) {}

  handleConnection(client: WebSocket, request: IncomingMessage): void {
    const state = this.sessions.open(client, request, 'foremanNotifications', {
      allow: ['foreman', 'admin', 'worker'],
    });

    // Room membership has to wait for the handshake, but the socket is already
    // registered, so a publish that lands in between simply misses this one
    // client rather than throwing.
    void state.ready.then(() => {
      const principal = state.principal;
      if (principal && isForeman(principal)) {
        this.registry.join(client, foremenRoom(principal.companyId));
      }
    });
  }

  handleDisconnect(client: WebSocket): void {
    this.sessions.close(client);
  }

  /**
   * The worker device's best-effort announcement that it uploaded a report.
   *
   * Almost always redundant -- the HTTP upload created the report and fanned out
   * already -- so this resolves to the same idempotency key and does nothing.
   * It earns its place in the rare case where the upload succeeded but the
   * response never made it back, or a report reached the server by some other
   * route: the foreman still gets told.
   */
  @SubscribeMessage(FrameType.WORKER_REPORT_SUBMITTED)
  async onWorkerReportSubmitted(
    @ConnectedSocket() client: WebSocket,
    @MessageBody() raw: unknown,
  ): Promise<unknown> {
    const state = await this.sessions.settled(client);
    const principal = state?.principal;
    if (!principal) {
      return errorFrame(ErrorCode.NOT_AUTHENTICATED_YET, 'This connection is not authenticated.');
    }

    if (isForeman(principal)) {
      return errorFrame(ErrorCode.SEND_NOT_ALLOWED, 'This channel is receive-only for foremen.');
    }

    const parsed = workerReportSubmittedFrameSchema.safeParse(raw);
    if (!parsed.success) {
      const issue = parsed.error.issues[0];
      return errorFrame(
        ErrorCode.VALIDATION_FAILED,
        issue ? `${issue.path.join('.') || 'frame'}: ${issue.message}` : 'Invalid report frame.',
      );
    }
    const frame = parsed.data;

    try {
      // The token settles who this is; the frame's own `employeeId` is ignored.
      const { outcome } = await this.reports.ingestOutOfBandNotice(principal.companyId, {
        ...frame,
        employeeId: principal.employeeId,
      });
      // Acking a notice the server discarded would tell the device it landed.
      if (outcome === 'unknownPhase') {
        return errorFrame(ErrorCode.NOT_FOUND, 'No such phase in this project.');
      }
      return ackFrame(FrameType.WORKER_REPORT_SUBMITTED, outcome === 'duplicate');
    } catch (error) {
      // Never propagate: an exception here would reach the global filter with no
      // HTTP response to write to, and the client would learn nothing.
      this.logger.error(
        `Failed to ingest an out-of-band report notice for phase ${frame.phaseId}: ` +
          `${error instanceof Error ? error.message : String(error)}`,
      );
      return errorFrame(ErrorCode.INTERNAL_ERROR, 'Could not record this report notice.');
    }
  }
}
