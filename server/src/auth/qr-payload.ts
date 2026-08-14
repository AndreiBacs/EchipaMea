import { WORKER_LOGIN_TICKET_TYPE, type WorkerLoginQrPayload } from './dto/worker-ticket.dto';

/**
 * Port of `SessionNotifier._extractJsonPayload` in the Flutter app.
 *
 * A scanner may return the raw JSON, or a URL that carries it in a `payload`
 * query parameter either plainly or base64-encoded. Accepting all three here
 * means the redeem endpoint tolerates exactly what the app already tolerates,
 * so QR codes printed by any client version keep working.
 */
export function extractJsonPayload(raw: string): string {
  const trimmed = raw.trim();
  if (trimmed.length === 0) return trimmed;
  if (trimmed.startsWith('{')) return trimmed;

  let url: URL;
  try {
    url = new URL(trimmed);
  } catch {
    return trimmed;
  }

  const queryPayload = url.searchParams.get('payload');
  if (!queryPayload) return trimmed;

  if (queryPayload.startsWith('{')) return queryPayload;

  try {
    // `base64url` also decodes standard base64 with +/ characters.
    const decoded = Buffer.from(queryPayload, 'base64url').toString('utf8');
    return decoded.startsWith('{') ? decoded : queryPayload;
  } catch {
    return queryPayload;
  }
}

export interface ParsedQrPayload {
  ticketId: string;
  employeeId?: string;
  employeeName?: string;
  expiresAt?: string;
}

/**
 * Pulls the ticket id out of a scanned payload.
 *
 * Only `ticketId` is trusted downstream -- the employee identity in the QR is a
 * display hint, since the authoritative identity comes from the ticket row.
 */
export function parseQrPayload(raw: string): ParsedQrPayload | undefined {
  const json = extractJsonPayload(raw);
  if (!json.startsWith('{')) {
    // Not JSON at all: treat the whole string as a bare ticket id.
    const bare = raw.trim();
    return bare.length > 0 ? { ticketId: bare } : undefined;
  }

  let parsed: unknown;
  try {
    parsed = JSON.parse(json);
  } catch {
    return undefined;
  }

  if (typeof parsed !== 'object' || parsed === null) return undefined;
  const record = parsed as Partial<WorkerLoginQrPayload>;

  if (record.type !== WORKER_LOGIN_TICKET_TYPE) return undefined;
  if (typeof record.ticketId !== 'string' || record.ticketId.length === 0) return undefined;

  return {
    ticketId: record.ticketId,
    employeeId: typeof record.employeeId === 'string' ? record.employeeId : undefined,
    employeeName: typeof record.employeeName === 'string' ? record.employeeName : undefined,
    expiresAt: typeof record.expiresAt === 'string' ? record.expiresAt : undefined,
  };
}

export function buildQrPayload(input: {
  ticketId: string;
  employeeId: string;
  employeeName: string;
  issuedAt: Date;
  expiresAt: Date;
}): WorkerLoginQrPayload {
  return {
    type: WORKER_LOGIN_TICKET_TYPE,
    ticketId: input.ticketId,
    employeeId: input.employeeId,
    employeeName: input.employeeName,
    issuedAt: input.issuedAt.toISOString(),
    expiresAt: input.expiresAt.toISOString(),
  };
}
