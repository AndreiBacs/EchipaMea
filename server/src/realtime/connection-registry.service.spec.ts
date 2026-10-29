import type { WebSocket } from 'ws';
import { ConnectionRegistryService, foremenRoom } from './connection-registry.service';

interface FakeSocket {
  readyState: number;
  OPEN: number;
  sent: string[];
  pings: number;
  terminated: boolean;
  closed?: { code: number; reason: string };
  listeners: Record<string, (() => void)[]>;
  on(event: string, handler: () => void): void;
  emit(event: string): void;
  send(payload: string): void;
  ping(): void;
  terminate(): void;
  close(code: number, reason: string): void;
}

function socket(open = true): FakeSocket {
  const self: FakeSocket = {
    readyState: open ? 1 : 3,
    OPEN: 1,
    sent: [],
    pings: 0,
    terminated: false,
    listeners: {},
    on(event, handler) {
      (self.listeners[event] ??= []).push(handler);
    },
    emit(event) {
      for (const handler of self.listeners[event] ?? []) handler();
    },
    send(payload) {
      self.sent.push(payload);
    },
    ping() {
      self.pings++;
    },
    terminate() {
      self.terminated = true;
    },
    close(code, reason) {
      self.closed = { code, reason };
      self.readyState = 3;
    },
  };
  return self;
}

const asWs = (fake: FakeSocket) => fake as unknown as WebSocket;

function registry(heartbeatMs = 0): ConnectionRegistryService {
  return new ConnectionRegistryService({ realtimeHeartbeatIntervalMs: heartbeatMs } as never);
}

describe('ConnectionRegistryService', () => {
  it('delivers a broadcast only to members of the room', () => {
    const service = registry();
    const inRoom = socket();
    const elsewhere = socket();

    service.attach(asWs(inRoom), 'foremanNotifications');
    service.attach(asWs(elsewhere), 'foremanNotifications');
    service.join(asWs(inRoom), foremenRoom('company_1'));
    service.join(asWs(elsewhere), foremenRoom('company_2'));

    const delivered = service.publishToForemen('company_1', { type: 'x' });

    expect(delivered).toBe(1);
    expect(inRoom.sent).toEqual(['{"type":"x"}']);
    expect(elsewhere.sent).toEqual([]);
  });

  it('is a no-op when nobody is listening', () => {
    const service = registry();
    expect(service.publishToForemen('company_1', { type: 'x' })).toBe(0);
  });

  it('skips sockets that are not open', () => {
    const service = registry();
    const closing = socket(false);
    service.attach(asWs(closing), 'foremanNotifications');
    service.join(asWs(closing), foremenRoom('company_1'));

    expect(service.publishToForemen('company_1', { type: 'x' })).toBe(0);
    expect(closing.sent).toEqual([]);
  });

  it('one failing socket does not stop delivery to the rest', () => {
    const service = registry();
    const broken = socket();
    broken.send = () => {
      throw new Error('EPIPE');
    };
    const healthy = socket();
    service.attach(asWs(broken), 'foremanNotifications');
    service.attach(asWs(healthy), 'foremanNotifications');
    service.join(asWs(broken), foremenRoom('c1'));
    service.join(asWs(healthy), foremenRoom('c1'));

    expect(service.publishToForemen('c1', { type: 'x' })).toBe(1);
    expect(healthy.sent).toHaveLength(1);
  });

  it('removes a socket from every room it joined', () => {
    const service = registry();
    const client = socket();
    service.attach(asWs(client), 'foremanNotifications');
    service.join(asWs(client), foremenRoom('c1'));

    service.forget(asWs(client));

    expect(service.publishToForemen('c1', { type: 'x' })).toBe(0);
    expect(service.stats().sockets).toBe(0);
    expect(service.stats().rooms).toBe(0);
    expect(service.stateOf(asWs(client))).toBeUndefined();
  });

  it('counts open sockets per channel', () => {
    const service = registry();
    service.attach(asWs(socket()), 'workerTelemetry');
    service.attach(asWs(socket()), 'foremanNotifications');
    service.attach(asWs(socket()), 'foremanNotifications');

    expect(service.stats()).toMatchObject({
      sockets: 3,
      byChannel: { workerTelemetry: 1, foremanNotifications: 2 },
    });
  });

  describe('heartbeat', () => {
    beforeEach(() => jest.useFakeTimers());
    afterEach(() => jest.useRealTimers());

    it('pings a live socket instead of closing it', () => {
      // The clients have no reconnect logic, so a healthy connection must never
      // be dropped by the server.
      const service = registry(1000);
      const client = socket();
      service.attach(asWs(client), 'workerTelemetry');
      service.onModuleInit();

      jest.advanceTimersByTime(1000);
      expect(client.pings).toBe(1);
      expect(client.terminated).toBe(false);

      // The socket answers, so the next round pings again rather than reaping.
      client.emit('pong');
      jest.advanceTimersByTime(1000);
      expect(client.pings).toBe(2);
      expect(client.terminated).toBe(false);
    });

    it('reaps a socket that missed the previous ping', () => {
      const service = registry(1000);
      const client = socket();
      service.attach(asWs(client), 'workerTelemetry');
      service.join(asWs(client), foremenRoom('c1'));
      service.onModuleInit();

      jest.advanceTimersByTime(1000); // ping, no pong answered
      jest.advanceTimersByTime(1000); // still unanswered -> terminate

      expect(client.terminated).toBe(true);
      expect(service.stats().sockets).toBe(0);
      expect(service.publishToForemen('c1', { type: 'x' })).toBe(0);
    });
  });

  it('closes open sockets with 1001 when the module is destroyed', async () => {
    const service = registry();
    const client = socket();
    service.attach(asWs(client), 'foremanNotifications');

    const destroyed = service.onModuleDestroy();
    jest.useFakeTimers();
    jest.advanceTimersByTime(100);
    jest.useRealTimers();
    await destroyed;

    expect(client.closed).toEqual({ code: 1001, reason: 'Server shutting down' });
    expect(service.stats().sockets).toBe(0);
  });
});
