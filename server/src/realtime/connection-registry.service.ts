import { Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import WsSocket, { type WebSocket } from 'ws';
import { ulid } from 'ulid';
import { AppConfig } from '../common/config/configuration';
import { WsCloseCode } from '../common/errors/error-codes';
import type { Principal } from '../common/auth/principal';
import type { RealtimeChannel } from './frames';

/** Attached to the socket object itself; there is nowhere else to hang it. */
const STATE = Symbol.for('echipamea.ws.state');

export interface SocketState {
  id: string;
  channel: RealtimeChannel;
  /**
   * Resolves once the handshake has finished deciding who this is. It never
   * rejects -- failure is expressed as `principal` staying undefined, and the
   * socket having been closed.
   */
  ready: Promise<void>;
  principal?: Principal;
  rooms: Set<string>;
  isAlive: boolean;
  openedAt: number;
  remote?: string;
}

interface Stateful {
  [STATE]?: SocketState;
}

export function foremenRoom(companyId: string): string {
  return `company:${companyId}:foremen`;
}

/** Writable right now. Anything else is closing, closed, or still handshaking. */
export function isOpen(socket: WebSocket): boolean {
  return socket.readyState === WsSocket.OPEN;
}

/**
 * Owns every open socket, the rooms they belong to, liveness, and fan-out.
 *
 * Deliberately free of domain dependencies so the modules that *publish* events
 * (reports today, notifications next) can inject it without importing the
 * gateways that would import them back.
 */
@Injectable()
export class ConnectionRegistryService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(ConnectionRegistryService.name);
  private readonly sockets = new Set<WebSocket>();
  private readonly rooms = new Map<string, Set<WebSocket>>();
  private heartbeat?: NodeJS.Timeout;

  constructor(private readonly config: AppConfig) {}

  onModuleInit(): void {
    const interval = this.config.realtimeHeartbeatIntervalMs;
    if (interval <= 0) return;
    this.heartbeat = setInterval(() => this.sweep(), interval);
    // Liveness checking must not be the reason a finished process stays alive.
    this.heartbeat.unref();
  }

  /**
   * Graceful drain, as `onModuleDestroy` rather than `onApplicationShutdown`.
   *
   * Nest runs destroy hooks, then disposes the socket module -- which calls
   * `terminate()` on every client -- and only then runs shutdown hooks. A 1001
   * sent from a shutdown hook would arrive after the socket was already ripped
   * out from under it.
   */
  async onModuleDestroy(): Promise<void> {
    if (this.heartbeat) clearInterval(this.heartbeat);
    if (this.sockets.size === 0) return;

    this.logger.log(`Draining ${this.sockets.size} realtime connection(s).`);
    for (const socket of this.sockets) {
      try {
        socket.close(WsCloseCode.GOING_AWAY, 'Server shutting down');
      } catch {
        // Already gone; nothing to drain.
      }
    }
    this.sockets.clear();
    this.rooms.clear();
    // Give the close frames a tick to flush before the adapter terminates.
    await new Promise((resolve) => setTimeout(resolve, 50));
  }

  // --- Membership ----------------------------------------------------------

  attach(socket: WebSocket, channel: RealtimeChannel, remote?: string): SocketState {
    const state: SocketState = {
      id: ulid(),
      channel,
      // Replaced synchronously by the gateway with the real handshake promise.
      ready: Promise.resolve(),
      rooms: new Set(),
      isAlive: true,
      openedAt: Date.now(),
      remote,
    };
    (socket as Stateful)[STATE] = state;
    this.sockets.add(socket);

    socket.on('pong', () => {
      state.isAlive = true;
    });

    return state;
  }

  stateOf(socket: WebSocket): SocketState | undefined {
    return (socket as Stateful)[STATE];
  }

  join(socket: WebSocket, room: string): void {
    const state = this.stateOf(socket);
    const members = this.rooms.get(room) ?? new Set<WebSocket>();
    members.add(socket);
    this.rooms.set(room, members);
    state?.rooms.add(room);
  }

  forget(socket: WebSocket): void {
    const state = this.stateOf(socket);
    this.sockets.delete(socket);
    for (const room of state?.rooms ?? []) {
      const members = this.rooms.get(room);
      if (!members) continue;
      members.delete(socket);
      if (members.size === 0) this.rooms.delete(room);
    }
    delete (socket as Stateful)[STATE];
  }

  // --- Fan-out -------------------------------------------------------------

  /** Returns how many sockets the frame was actually written to. */
  broadcast(room: string, frame: unknown): number {
    const members = this.rooms.get(room);
    if (!members || members.size === 0) return 0;

    const payload = JSON.stringify(frame);
    let delivered = 0;
    for (const socket of members) {
      if (!isOpen(socket)) continue;
      try {
        socket.send(payload);
        delivered++;
      } catch (error) {
        this.logger.warn(`Failed to deliver to a socket in ${room}: ${describe(error)}`);
      }
    }
    return delivered;
  }

  /** Fan-out to every foreman currently watching this company. */
  publishToForemen(companyId: string, frame: unknown): number {
    return this.broadcast(foremenRoom(companyId), frame);
  }

  stats(): { sockets: number; rooms: number; byChannel: Record<string, number> } {
    const byChannel: Record<string, number> = {};
    for (const socket of this.sockets) {
      const channel = this.stateOf(socket)?.channel ?? 'unknown';
      byChannel[channel] = (byChannel[channel] ?? 0) + 1;
    }
    return { sockets: this.sockets.size, rooms: this.rooms.size, byChannel };
  }

  /**
   * Ping every socket; drop the ones that did not answer the previous round.
   *
   * This only ever closes connections that have already stopped responding --
   * a healthy socket is never disturbed, because the client has no reconnect.
   */
  private sweep(): void {
    for (const socket of [...this.sockets]) {
      const state = this.stateOf(socket);
      if (!state) {
        this.sockets.delete(socket);
        continue;
      }

      if (!state.isAlive) {
        this.logger.debug(`Terminating unresponsive socket ${state.id} (${state.channel}).`);
        this.forget(socket);
        socket.terminate();
        continue;
      }

      state.isAlive = false;
      try {
        socket.ping();
      } catch {
        this.forget(socket);
        socket.terminate();
      }
    }
  }
}

function describe(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}
