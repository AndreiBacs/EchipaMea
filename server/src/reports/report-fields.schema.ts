import { z } from 'zod';
import { parseFlexibleIso } from '../common/util/iso';

/**
 * The exact multipart shape the Flutter worker app sends.
 *
 * From `worker_reports_api.dart`, text fields in insertion order:
 *   projectId, projectName, phaseId, phaseName, employeeId, employeeName,
 *   description, submittedAt, then photoNames[0], photoNames[1], ...
 *
 * File parts:
 *   photos[]   -- repeated once per photo, the field name literally contains
 *                 the square brackets
 *   voiceMemo  -- optional, single
 *
 * Both are sent as application/octet-stream, so part content types are ignored
 * and the bytes are sniffed instead.
 */

export const PHOTOS_FIELD = 'photos[]';
export const VOICE_MEMO_FIELD = 'voiceMemo';

/**
 * `submittedAt` is kept as a raw string as well as a parsed instant.
 *
 * Dart emits `toIso8601String()` on a UTC DateTime: six fractional digits on
 * mobile, three on web. JavaScript `Date` truncates to milliseconds, so
 * re-serialising it would produce a different string -- and the idempotency key
 * is a hash of that string. Hashing the raw text is what lets the HTTP upload
 * and the worker's follow-up WebSocket frame agree on one key.
 */
export const reportFieldsSchema = z.object({
  projectId: z.string().trim().min(1, 'projectId is required.'),
  projectName: z.string().trim().default(''),
  phaseId: z.string().trim().min(1, 'phaseId is required.'),
  phaseName: z.string().trim().default(''),
  employeeId: z.string().trim().default(''),
  employeeName: z.string().trim().default(''),
  description: z.string().default(''),
  submittedAt: z
    .string()
    .trim()
    .min(1, 'submittedAt is required.')
    .refine((value) => parseFlexibleIso(value) !== undefined, {
      message: 'submittedAt must be an ISO-8601 timestamp.',
    }),
});

export type ReportFields = z.infer<typeof reportFieldsSchema>;

/**
 * Collects `photoNames[0]`, `photoNames[1]`, ... into a positional array.
 *
 * OpenAPI cannot express indexed form fields, which is why the draft spec had
 * the placeholder `photoNames[index]`. Sparse or out-of-order indices are
 * tolerated: the array is filled by position and gaps become empty strings, so
 * one missing name never shifts the rest out of alignment with the photos.
 */
export function collectPhotoNames(body: Record<string, unknown>): string[] {
  const byIndex = new Map<number, string>();

  for (const [key, value] of Object.entries(body)) {
    const match = /^photoNames\[(\d+)\]$/.exec(key);
    if (!match?.[1]) continue;
    const index = Number(match[1]);
    if (!Number.isInteger(index) || index < 0) continue;
    byIndex.set(index, typeof value === 'string' ? value : String(value));
  }

  if (byIndex.size === 0) return [];
  const highest = Math.max(...byIndex.keys());
  return Array.from({ length: highest + 1 }, (_, i) => byIndex.get(i) ?? '');
}

/**
 * Normalises a multipart text body.
 *
 * Some parsers hand back repeated fields as arrays; the first value wins, which
 * matches how the client sends each text field exactly once.
 */
export function flattenBody(body: Record<string, unknown>): Record<string, unknown> {
  const flat: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(body)) {
    flat[key] = Array.isArray(value) ? value[0] : value;
  }
  return flat;
}
