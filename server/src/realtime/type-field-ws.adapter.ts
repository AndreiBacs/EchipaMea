import { WsAdapter } from '@nestjs/platform-ws';
import type { MessageMappingProperties } from '@nestjs/websockets';
import { EMPTY, Observable, of } from 'rxjs';
import { ErrorCode } from '../common/errors/error-codes';
import { errorFrame } from './frames';

/**
 * A WebSocket adapter that dispatches on a top-level `type` field.
 *
 * Nest ships two transports and neither speaks the client's protocol.
 * `platform-socket.io` is a different wire format entirely, and the stock
 * `WsAdapter` expects `{"event": "...", "data": {...}}` -- an envelope the
 * Flutter app never sends. With the default adapter the socket handshakes, the
 * app publishes happily, and every frame is silently dropped, which looks
 * exactly like a working connection with no traffic.
 *
 * The app sends flat frames instead:
 *
 *   {"type": "worker_location", "latitude": 46.7, "longitude": 23.6, ...}
 *
 * so `type` selects the `@SubscribeMessage` handler and the *whole frame* is
 * handed to it as the payload.
 *
 * Two further departures from the base class, both because the client listens
 * with `cancelOnError: true` and never reconnects:
 *
 *   - An unroutable frame answers with an `error` frame. The base class returns
 *     EMPTY, so a client typo is indistinguishable from a healthy silent server.
 *   - A handler that throws answers with an `error` frame rather than tearing
 *     down the message stream for the rest of the connection.
 */
export class TypeFieldWsAdapter extends WsAdapter {
  override bindMessageHandler(
    buffer: { data?: unknown },
    handlersMap: Map<string, MessageMappingProperties>,
    transform: (data: unknown) => Observable<unknown>,
  ): Observable<unknown> {
    const text = decode(buffer?.data);
    if (text === undefined) {
      // A binary frame on a JSON-only protocol. Nothing to answer to.
      return EMPTY;
    }

    let frame: unknown;
    try {
      frame = JSON.parse(text);
    } catch {
      return of(errorFrame(ErrorCode.MALFORMED_FRAME, 'Frame is not valid JSON.'));
    }

    if (typeof frame !== 'object' || frame === null || Array.isArray(frame)) {
      return of(errorFrame(ErrorCode.MALFORMED_FRAME, 'Frame must be a JSON object.'));
    }

    const type = (frame as { type?: unknown }).type;
    if (typeof type !== 'string' || type.length === 0) {
      return of(errorFrame(ErrorCode.MALFORMED_FRAME, 'Frame is missing a "type" field.'));
    }

    const handler = handlersMap.get(type);
    if (!handler) {
      return of(
        errorFrame(ErrorCode.UNKNOWN_MESSAGE_TYPE, `This channel does not accept "${type}".`),
      );
    }

    try {
      // `callback` was bound to the socket by Nest, so the handler receives
      // (client, frame, type) and `@MessageBody()` resolves to the whole frame.
      return transform(handler.callback(frame, type));
    } catch (error) {
      return of(errorFrame(ErrorCode.INTERNAL_ERROR, describe(error)));
    }
  }
}

/** `ws` hands over a string, a Buffer, or -- for fragmented frames -- Buffer[]. */
function decode(data: unknown): string | undefined {
  if (typeof data === 'string') return data;
  if (Buffer.isBuffer(data)) return data.toString('utf8');
  if (Array.isArray(data) && data.every((part): part is Buffer => Buffer.isBuffer(part))) {
    return Buffer.concat(data).toString('utf8');
  }
  if (data instanceof ArrayBuffer) return Buffer.from(data).toString('utf8');
  return undefined;
}

function describe(error: unknown): string {
  return error instanceof Error ? error.message : 'Unexpected server error.';
}
