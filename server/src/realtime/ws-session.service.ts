import { HttpStatus, Injectable, Logger } from '@nestjs/common';
import type { IncomingMessage } from 'node:http';
import type { WebSocket } from 'ws';
import { AppConfig } from '../common/config/configuration';
import { AppException } from '../common/errors/app-exception';
import { ErrorCode, WsCloseCode } from '../common/errors/error-codes';
import { principalLabel, type PrincipalRole } from '../common/auth/principal';
import { ConnectionRegistryService, isOpen, type SocketState } from './connection-registry.service';
import { FrameType, errorFrame, type ConnectedFrame, type RealtimeChannel } from './frames';
import { WsAuthService } from './ws-auth.service';

export interface OpenOptions {
  /** Roles allowed on this channel at all. Anything else is closed with 4403. */
  allow: PrincipalRole[];
}

/**
 * The connect half of both gateways: authenticate, admit or close, announce.
 */
@Injectable()
export class WsSessionService {
  private readonly logger = new Logger(WsSessionService.name);

  constructor(
    private readonly registry: ConnectionRegistryService,
    private readonly auth: WsAuthService,
    private readonly config: AppConfig,
  ) {}

  /**
   * Must stay synchronous up to the point the state is attached.
   *
   * Nest's `WebSocketsController` calls `handleConnection` and then immediately
   * binds the message handlers, without waiting. The worker's report notice is a
   * connect-send-close in a few milliseconds, so its frame can and does arrive
   * before authentication has finished. Attaching the state -- and the `ready`
   * promise on it -- before the first `await` is what lets a handler wait for
   * the answer instead of racing it.
   */
  open(
    client: WebSocket,
    request: IncomingMessage,
    channel: RealtimeChannel,
    options: OpenOptions,
  ): SocketState {
    const state = this.registry.attach(client, channel, remoteOf(request));
    state.ready = this.handshake(client, request, state, options);
    return state;
  }

  /** Waits for the handshake, then hands back the socket's state. */
  async settled(client: WebSocket): Promise<SocketState | undefined> {
    const state = this.registry.stateOf(client);
    if (!state) return undefined;
    await state.ready;
    return state;
  }

  close(client: WebSocket): void {
    const state = this.registry.stateOf(client);
    if (state) {
      this.logger.debug(
        `Socket ${state.id} closed after ${Math.round((Date.now() - state.openedAt) / 1000)}s.`,
      );
    }
    this.registry.forget(client);
  }

  private async handshake(
    client: WebSocket,
    request: IncomingMessage,
    state: SocketState,
    options: OpenOptions,
  ): Promise<void> {
    try {
      const principal = await this.auth.authenticate(request);

      if (!options.allow.includes(principal.role)) {
        throw AppException.forbidden(`The ${principal.role} role is not accepted on this channel.`);
      }

      state.principal = principal;
      this.send(client, {
        type: FrameType.CONNECTED,
        channel: state.channel,
        role: principal.role,
        serverTime: new Date().toISOString(),
        heartbeatIntervalMs: this.config.realtimeHeartbeatIntervalMs,
      } satisfies ConnectedFrame);

      this.logger.log(
        `${state.channel} socket ${state.id} open for ${principalLabel(principal)} ` +
          `(company ${principal.companyId}).`,
      );
    } catch (error) {
      const { code, reason, errorCode } = closeFor(error);
      this.logger.warn(`Rejecting ${state.channel} socket ${state.id}: ${reason}`);
      // The error frame goes out before the close so a developer sees a reason
      // rather than an opaque close code.
      this.send(client, errorFrame(errorCode, reason));
      try {
        client.close(code, reason.slice(0, 120));
      } catch {
        // Already gone.
      }
    }
  }

  private send(client: WebSocket, frame: unknown): void {
    if (!isOpen(client)) return;
    try {
      client.send(JSON.stringify(frame));
    } catch {
      // The socket died between the check and the write; nothing to do.
    }
  }
}

function closeFor(error: unknown): { code: number; reason: string; errorCode: string } {
  if (error instanceof AppException) {
    const forbidden: number = HttpStatus.FORBIDDEN;
    return {
      code: error.getStatus() === forbidden ? WsCloseCode.FORBIDDEN : WsCloseCode.UNAUTHENTICATED,
      reason: error.message,
      errorCode: error.code,
    };
  }
  return {
    code: WsCloseCode.UNAUTHENTICATED,
    reason: 'Could not authenticate this connection.',
    errorCode: ErrorCode.UNAUTHENTICATED,
  };
}

function remoteOf(request: IncomingMessage): string | undefined {
  const forwarded = request.headers['x-forwarded-for'];
  const first = Array.isArray(forwarded) ? forwarded[0] : forwarded;
  if (first) return first.split(',')[0]?.trim();
  return request.socket.remoteAddress ?? undefined;
}
