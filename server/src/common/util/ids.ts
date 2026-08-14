import { createHash, randomBytes, timingSafeEqual } from 'node:crypto';
import { ulid } from 'ulid';

/** Opaque, high-entropy secret for QR and realtime tickets. */
export function generateSecret(prefix: string, bytes = 32): string {
  return `${prefix}${randomBytes(bytes).toString('base64url')}`;
}

/**
 * Tickets and refresh tokens are stored hashed, never in plaintext: a database
 * leak must not hand out working credentials.
 */
export function hashSecret(secret: string): string {
  return createHash('sha256').update(secret, 'utf8').digest('hex');
}

export function sha256Hex(input: string | Buffer): string {
  return createHash('sha256').update(input).digest('hex');
}

/** Constant-time comparison for anything secret-adjacent. */
export function safeEquals(a: string, b: string): boolean {
  const bufA = Buffer.from(a, 'utf8');
  const bufB = Buffer.from(b, 'utf8');
  if (bufA.length !== bufB.length) return false;
  return timingSafeEqual(bufA, bufB);
}

/** Sortable id for storage keys, so object listings are chronological. */
export function storageId(): string {
  return ulid().toLowerCase();
}

export function newSessionId(): string {
  return ulid();
}

/**
 * Stable key that dedupes a worker report across its two arrival paths: the
 * multipart HTTP upload and the best-effort WebSocket frame the worker device
 * sends immediately afterwards.
 *
 * `submittedAtRaw` is the client's timestamp string verbatim, because Dart
 * emits 6 fractional digits on mobile while JS `Date` truncates to 3 -- hashing
 * a re-serialised timestamp would produce two different keys for one report.
 */
export function reportIdempotencyKey(input: {
  companyId: string;
  phaseId: string;
  employeeId: string;
  submittedAtRaw: string;
}): string {
  return sha256Hex(
    `${input.companyId}|${input.phaseId}|${input.employeeId}|${input.submittedAtRaw}`,
  );
}
