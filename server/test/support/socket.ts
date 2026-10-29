import WebSocket from 'ws';

export type Frame = { type: string } & Record<string, unknown>;

/**
 * A raw RFC-6455 client that buffers frames, so a test can `await` the next
 * frame of a given type without racing the server -- the `connected` frame is
 * typically sent before the caller has attached a listener.
 */
export class TestSocket {
  private readonly frames: Frame[] = [];
  private readonly waiters: { type?: string; resolve(frame: Frame): void }[] = [];
  readonly closed: Promise<{ code: number; reason: string }>;

  constructor(readonly ws: WebSocket) {
    ws.on('message', (data: WebSocket.RawData) => {
      const frame = JSON.parse(rawToString(data)) as Frame;
      const index = this.waiters.findIndex((w) => !w.type || w.type === frame.type);
      if (index >= 0) {
        const [waiter] = this.waiters.splice(index, 1);
        waiter!.resolve(frame);
      } else {
        this.frames.push(frame);
      }
    });
    this.closed = new Promise((resolve) => {
      ws.on('close', (code, reason) => resolve({ code, reason: reason.toString() }));
    });
  }

  /** Resolves with the next frame (of `type`, if given), buffered or future. */
  next(type?: string, timeoutMs = 5000): Promise<Frame> {
    const index = this.frames.findIndex((f) => !type || f.type === type);
    if (index >= 0) return Promise.resolve(this.frames.splice(index, 1)[0]!);

    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        const at = this.waiters.indexOf(waiter);
        if (at >= 0) this.waiters.splice(at, 1);
        reject(new Error(`No ${type ?? 'any'} frame within ${timeoutMs}ms`));
      }, timeoutMs);
      const waiter = {
        type,
        resolve: (frame: Frame) => {
          clearTimeout(timer);
          resolve(frame);
        },
      };
      this.waiters.push(waiter);
    });
  }

  /** Asserts that no frame of `type` arrives within `ms`. */
  async expectSilence(type: string, ms = 750): Promise<void> {
    await expect(this.next(type, ms)).rejects.toThrow(/No .* frame within/);
  }

  send(frame: unknown): void {
    this.ws.send(typeof frame === 'string' ? frame : JSON.stringify(frame));
  }

  async close(): Promise<void> {
    if (this.ws.readyState === WebSocket.CLOSED) return;
    this.ws.close();
    await this.closed;
  }
}

function rawToString(data: WebSocket.RawData): string {
  if (Array.isArray(data)) return Buffer.concat(data).toString('utf8');
  if (Buffer.isBuffer(data)) return data.toString('utf8');
  return Buffer.from(data).toString('utf8');
}

/**
 * Opens a socket and resolves once the handshake completes. Rejected auth is
 * not a handshake failure here: the server upgrades, sends an `error` frame and
 * closes with 4401, which a test observes through `closed`.
 */
export function openSocket(
  url: string,
  options: { headers?: Record<string, string> } = {},
): Promise<TestSocket> {
  return new Promise((resolve, reject) => {
    const ws = new WebSocket(url, { headers: options.headers });
    const socket = new TestSocket(ws);
    ws.once('open', () => resolve(socket));
    ws.once('error', reject);
  });
}
