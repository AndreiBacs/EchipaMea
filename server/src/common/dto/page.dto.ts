import { z } from 'zod';
import { AppException } from '../errors/app-exception';

/**
 * Cursor pagination for every list endpoint.
 *
 * The draft spec returned bare arrays. Nothing consumes those endpoints yet, so
 * introducing the envelope now is free -- and retrofitting pagination after the
 * Flutter client is built around `List<T>` would mean rewriting the same pages
 * a second time.
 */

export const DEFAULT_PAGE_LIMIT = 50;
export const MAX_PAGE_LIMIT = 200;

export const pageQuerySchema = z.object({
  limit: z.coerce.number().int().min(1).max(MAX_PAGE_LIMIT).default(DEFAULT_PAGE_LIMIT),
  cursor: z.string().optional(),
  withTotal: z
    .enum(['true', 'false'])
    .optional()
    .transform((v) => v === 'true'),
});

export type PageQuery = z.infer<typeof pageQuerySchema>;

export interface PageInfo {
  limit: number;
  nextCursor?: string;
  total?: number;
}

export interface Paged<T> {
  items: T[];
  page: PageInfo;
}

interface CursorPayload {
  /** Value of the sort column at the boundary row. */
  k: string;
  /** Tie-breaker id, so rows with equal sort keys still paginate stably. */
  i: string;
}

export function encodeCursor(sortKey: string, id: string): string {
  const payload: CursorPayload = { k: sortKey, i: id };
  return Buffer.from(JSON.stringify(payload), 'utf8').toString('base64url');
}

export function decodeCursor(cursor: string): { sortKey: string; id: string } {
  try {
    const raw = Buffer.from(cursor, 'base64url').toString('utf8');
    const parsed: unknown = JSON.parse(raw);
    if (
      typeof parsed === 'object' &&
      parsed !== null &&
      typeof (parsed as CursorPayload).k === 'string' &&
      typeof (parsed as CursorPayload).i === 'string'
    ) {
      const payload = parsed as CursorPayload;
      return { sortKey: payload.k, id: payload.i };
    }
  } catch {
    // fall through
  }
  throw AppException.badRequest('Malformed pagination cursor.', 'cursor');
}

/**
 * Builds the `where.OR` that resumes a listing after `cursor`.
 *
 * The compound boundary -- "sort key strictly past the cursor, OR equal sort key
 * with a later id" -- is what makes pagination stable when the sort column is
 * not unique. Ordering by `name` alone would silently repeat or skip rows
 * whenever two clients or employees share a name.
 *
 * Returns undefined when there is no cursor, so callers can spread it away.
 */
export function cursorFilter(options: {
  sortField: string;
  descending: boolean;
  cursor?: string;
  /** Converts the encoded sort key back to its column type (e.g. a Date). */
  parseSortKey?: (raw: string) => unknown;
}): Record<string, unknown>[] | undefined {
  if (!options.cursor) return undefined;

  const { sortKey, id } = decodeCursor(options.cursor);
  const value = options.parseSortKey ? options.parseSortKey(sortKey) : sortKey;
  const comparator = options.descending ? 'lt' : 'gt';

  return [
    { [options.sortField]: { [comparator]: value } },
    { [options.sortField]: value, id: { [comparator]: id } },
  ];
}

/** Sort keys are encoded as strings; dates need converting back. */
export function parseDateSortKey(raw: string): Date {
  return new Date(raw);
}

/**
 * Builds the response envelope from one over-fetched page.
 *
 * Callers query `limit + 1` rows; the extra row is what proves another page
 * exists without a second count query.
 */
export function buildPage<T>(
  rows: T[],
  limit: number,
  toCursor: (row: T) => string,
  total?: number,
): Paged<T> {
  const hasMore = rows.length > limit;
  const items = hasMore ? rows.slice(0, limit) : rows;
  const last = items[items.length - 1];
  return {
    items,
    page: {
      limit,
      ...(hasMore && last ? { nextCursor: toCursor(last) } : {}),
      ...(total !== undefined ? { total } : {}),
    },
  };
}
