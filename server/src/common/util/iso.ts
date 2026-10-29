/**
 * The Flutter client emits `DateTime.toUtc().toIso8601String()`, which is
 * `2026-08-14T09:12:33.123456Z` on mobile (6 fractional digits) and
 * `...123Z` on web. Strict RFC-3339 parsers that assume milliseconds reject
 * the mobile form, so parsing is done leniently here and the original string is
 * kept alongside the parsed instant wherever it matters.
 */

const ISO_LIKE =
  /^(\d{4})-(\d{2})-(\d{2})[Tt ](\d{2}):(\d{2}):(\d{2})(?:\.(\d{1,9}))?(Z|z|[+-]\d{2}:?\d{2})?$/;

export function parseFlexibleIso(value: string): Date | undefined {
  const trimmed = value.trim();
  if (!ISO_LIKE.test(trimmed)) return undefined;
  const parsed = new Date(trimmed);
  return Number.isNaN(parsed.getTime()) ? undefined : parsed;
}

/**
 * Parses a client timestamp, falling back to "now" when it is missing or
 * unparseable. Report ingestion must not fail on a clock oddity from a phone.
 */
export function parseFlexibleIsoOrNow(value: string | undefined): Date {
  if (!value) return new Date();
  return parseFlexibleIso(value) ?? new Date();
}

export function toIsoString(value: Date): string {
  return value.toISOString();
}
