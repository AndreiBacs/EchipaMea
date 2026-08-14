import { buildQrPayload, extractJsonPayload, parseQrPayload } from './qr-payload';

describe('extractJsonPayload', () => {
  const json = '{"type":"foreman_worker_login_ticket","ticketId":"tkt_abc"}';

  it('returns raw JSON unchanged', () => {
    expect(extractJsonPayload(json)).toBe(json);
  });

  it('trims surrounding whitespace', () => {
    expect(extractJsonPayload(`  ${json}\n`)).toBe(json);
  });

  it('unwraps a URL carrying plain JSON in ?payload=', () => {
    const url = `https://app.example.com/worker-login?payload=${encodeURIComponent(json)}`;
    expect(extractJsonPayload(url)).toBe(json);
  });

  it('unwraps a URL carrying base64url JSON in ?payload=', () => {
    const encoded = Buffer.from(json, 'utf8').toString('base64url');
    const url = `echipamea://worker-login?payload=${encoded}`;
    expect(extractJsonPayload(url)).toBe(json);
  });

  it('returns the input when a URL has no payload parameter', () => {
    const url = 'https://app.example.com/worker-login';
    expect(extractJsonPayload(url)).toBe(url);
  });

  it('returns the input for a non-URL, non-JSON string', () => {
    expect(extractJsonPayload('tkt_bare_secret')).toBe('tkt_bare_secret');
  });
});

describe('parseQrPayload', () => {
  const payload = buildQrPayload({
    ticketId: 'tkt_abc',
    employeeId: 'e1',
    employeeName: 'Andrei D.',
    issuedAt: new Date('2026-08-14T09:00:00.000Z'),
    expiresAt: new Date('2026-08-14T09:01:30.000Z'),
  });
  const json = JSON.stringify(payload);

  it('parses raw JSON', () => {
    expect(parseQrPayload(json)).toMatchObject({
      ticketId: 'tkt_abc',
      employeeId: 'e1',
      employeeName: 'Andrei D.',
    });
  });

  it('parses a base64url-wrapped URL', () => {
    const encoded = Buffer.from(json, 'utf8').toString('base64url');
    expect(parseQrPayload(`https://x.test/l?payload=${encoded}`)?.ticketId).toBe('tkt_abc');
  });

  it('treats a bare non-JSON string as a ticket id', () => {
    expect(parseQrPayload('tkt_bare')).toEqual({ ticketId: 'tkt_bare' });
  });

  it('rejects JSON with the wrong discriminator', () => {
    expect(parseQrPayload('{"type":"something_else","ticketId":"x"}')).toBeUndefined();
  });

  it('rejects JSON without a ticketId', () => {
    expect(parseQrPayload('{"type":"foreman_worker_login_ticket"}')).toBeUndefined();
  });

  it('rejects malformed JSON', () => {
    expect(parseQrPayload('{not json')).toBeUndefined();
  });
});
