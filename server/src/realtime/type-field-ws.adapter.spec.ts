import type { MessageMappingProperties } from '@nestjs/websockets';
import { firstValueFrom, from, isObservable, of, mergeMap } from 'rxjs';
import { TypeFieldWsAdapter } from './type-field-ws.adapter';

/** Mirrors what `WebSocketsController` passes as `transform`. */
const transform = (data: unknown) =>
  from(Promise.resolve(data)).pipe(
    mergeMap((value) =>
      isObservable(value) ? value : value instanceof Promise ? from(value) : of(value),
    ),
  );

function adapter(): TypeFieldWsAdapter {
  // The constructor only wires an optional message parser and loads `ws`; no
  // application or HTTP server is needed to exercise the dispatch logic.
  return new TypeFieldWsAdapter();
}

function handlers(
  map: Record<string, (frame: unknown, type: string) => unknown>,
): Map<string, MessageMappingProperties> {
  const entries = new Map<string, MessageMappingProperties>();
  for (const [message, callback] of Object.entries(map)) {
    entries.set(message, { message, callback } as MessageMappingProperties);
  }
  return entries;
}

const emit = async (data: unknown, map: Map<string, MessageMappingProperties>): Promise<unknown> =>
  firstValueFrom(adapter().bindMessageHandler({ data }, map, transform));

describe('TypeFieldWsAdapter', () => {
  it('routes on the top-level `type` field', async () => {
    const seen: unknown[] = [];
    const map = handlers({
      worker_location: (frame) => {
        seen.push(frame);
        return { ok: true };
      },
    });

    const result = await emit(
      JSON.stringify({ type: 'worker_location', latitude: 46.7, longitude: 23.6 }),
      map,
    );

    expect(result).toEqual({ ok: true });
    // The *whole* frame is the payload, not a nested `data` property -- the
    // client sends flat objects with no envelope.
    expect(seen[0]).toEqual({ type: 'worker_location', latitude: 46.7, longitude: 23.6 });
  });

  it('passes the type through as the second argument', async () => {
    let received: string | undefined;
    const map = handlers({
      worker_location: (_frame, type) => {
        received = type;
        return undefined;
      },
    });
    await emit(JSON.stringify({ type: 'worker_location' }), map).catch(() => undefined);
    expect(received).toBe('worker_location');
  });

  it('decodes a Buffer payload', async () => {
    const map = handlers({ ping: () => ({ pong: true }) });
    const result = await emit(Buffer.from(JSON.stringify({ type: 'ping' }), 'utf8'), map);
    expect(result).toEqual({ pong: true });
  });

  it('decodes a fragmented Buffer[] payload', async () => {
    const text = JSON.stringify({ type: 'ping' });
    const split = [Buffer.from(text.slice(0, 4), 'utf8'), Buffer.from(text.slice(4), 'utf8')];
    const result = await emit(split, handlers({ ping: () => ({ pong: true }) }));
    expect(result).toEqual({ pong: true });
  });

  it('answers an unknown type with an error frame, not silence', async () => {
    // The stock adapter returns EMPTY here, which is indistinguishable from a
    // healthy server that simply has nothing to say.
    const result = await emit(JSON.stringify({ type: 'nope' }), handlers({ ping: () => null }));
    expect(result).toMatchObject({ type: 'error', code: 'UNKNOWN_MESSAGE_TYPE' });
    expect(result).toHaveProperty('message', expect.stringContaining('nope'));
  });

  it.each([
    ['not JSON', 'not json at all'],
    ['a JSON array', '[1,2,3]'],
    ['a JSON scalar', '"hello"'],
    ['an object with no type', '{"latitude":46.7}'],
    ['an object with a non-string type', '{"type":42}'],
  ])('answers %s with a malformed-frame error', async (_label, payload) => {
    const result = await emit(payload, handlers({ ping: () => null }));
    expect(result).toMatchObject({ type: 'error', code: 'MALFORMED_FRAME' });
  });

  it('converts a throwing handler into an error frame', async () => {
    // A thrown error would otherwise reach the global exception filter with no
    // HTTP response to write to, and tear down this socket's message stream.
    const map = handlers({
      boom: () => {
        throw new Error('handler exploded');
      },
    });
    const result = await emit(JSON.stringify({ type: 'boom' }), map);
    expect(result).toMatchObject({ type: 'error', code: 'INTERNAL_ERROR' });
  });

  it('stays silent on a binary frame', () => {
    const emitted: unknown[] = [];
    adapter()
      .bindMessageHandler({ data: 42 }, handlers({ ping: () => null }), transform)
      .subscribe((value) => emitted.push(value));
    expect(emitted).toEqual([]);
  });
});
