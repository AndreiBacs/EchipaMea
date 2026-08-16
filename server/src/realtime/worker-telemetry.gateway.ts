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
import { parseFlexibleIsoOrNow } from '../common/util/iso';
import { PrismaService } from '../common/prisma/prisma.service';
import { FrameType, ackFrame, errorFrame, workerLocationFrameSchema } from './frames';
import { WS_PATHS } from './realtime-ticket.service';
import { WsSessionService } from './ws-session.service';

/**
 * `/ws/worker-telemetry` -- workers publish periodic location fixes.
 *
 * Send-only by design: the app opens this socket, writes a `worker_location`
 * frame roughly every 30 minutes while inside the employee's configured working
 * hours, and ignores everything the server sends back.
 *
 * `maxPayload` is small on purpose. A location frame is a few hundred bytes and
 * nothing else is accepted here, so there is no reason to let an unauthenticated
 * upgrade buffer megabytes.
 */
@WebSocketGateway({ path: WS_PATHS.workerTelemetry, maxPayload: 16 * 1024 })
export class WorkerTelemetryGateway implements OnGatewayConnection, OnGatewayDisconnect {
  private readonly logger = new Logger(WorkerTelemetryGateway.name);

  constructor(
    private readonly sessions: WsSessionService,
    private readonly prisma: PrismaService,
  ) {}

  handleConnection(client: WebSocket, request: IncomingMessage): void {
    // Foremen have no reason to be here, and admitting them would mean deciding
    // what a foreman-authored location fix even means.
    this.sessions.open(client, request, 'workerTelemetry', { allow: ['worker'] });
  }

  handleDisconnect(client: WebSocket): void {
    this.sessions.close(client);
  }

  @SubscribeMessage(FrameType.WORKER_LOCATION)
  async onWorkerLocation(
    @ConnectedSocket() client: WebSocket,
    @MessageBody() raw: unknown,
  ): Promise<unknown> {
    const state = await this.sessions.settled(client);
    const principal = state?.principal;
    if (!principal) {
      return errorFrame(ErrorCode.NOT_AUTHENTICATED_YET, 'This connection is not authenticated.');
    }

    const parsed = workerLocationFrameSchema.safeParse(raw);
    if (!parsed.success) {
      const issue = parsed.error.issues[0];
      return errorFrame(
        ErrorCode.VALIDATION_FAILED,
        issue ? `${issue.path.join('.') || 'frame'}: ${issue.message}` : 'Invalid location frame.',
      );
    }
    const frame = parsed.data;

    // A worker token settles who this is. The frame's `employeeId` is only
    // consulted for anonymous legacy traffic, which cannot prove anything about
    // itself -- the same rule the HTTP report upload follows.
    const employeeId = principal.kind === 'employee' ? principal.employeeId : frame.employeeId;
    if (!employeeId) {
      return errorFrame(ErrorCode.VALIDATION_FAILED, 'employeeId is required.');
    }
    if (principal.kind === 'employee' && frame.employeeId && frame.employeeId !== employeeId) {
      this.logger.warn(
        `Employee ${employeeId} sent a location frame claiming ${frame.employeeId}; ` +
          'recording it against the token subject.',
      );
    }

    const employee = await this.prisma.employee.findFirst({
      where: { id: employeeId, companyId: principal.companyId, deletedAt: null },
      select: { id: true, name: true },
    });
    if (!employee) {
      return errorFrame(ErrorCode.NOT_FOUND, `Employee "${employeeId}" was not found.`);
    }

    await this.prisma.workerLocationSample.create({
      data: {
        companyId: principal.companyId,
        employeeId: employee.id,
        latitude: frame.latitude,
        longitude: frame.longitude,
        accuracyMeters: frame.accuracyMeters,
        // The client sends send-time wall clock, not the GPS fix time; the
        // column name says `capturedAt` because that is what the wire calls it.
        capturedAt: parseFlexibleIsoOrNow(frame.capturedAt || undefined),
        employeeNameSnapshot: frame.employeeName || employee.name,
      },
    });

    return ackFrame(FrameType.WORKER_LOCATION);
  }
}
