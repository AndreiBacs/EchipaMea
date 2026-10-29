/**
 * Day keys: bare calendar dates in `YYYY-MM-DD`, matching
 * `ProjectsNotifier.dayKey` in the Flutter app.
 *
 * These are NEVER timezone-converted. The client derives a day key from the
 * worker's local wall clock, so reinterpreting it in the server's zone would
 * silently shift a whole day's schedule for anyone in a different offset.
 * Postgres `DATE` columns store them as-is; `dayKeyToDate` deliberately builds
 * a UTC-midnight instant purely as a lossless carrier for that calendar date.
 */

const DAY_KEY_PATTERN = /^(\d{4})-(\d{2})-(\d{2})$/;

export class InvalidDayKeyError extends Error {
  constructor(value: string) {
    super(`Invalid day key "${value}". Expected YYYY-MM-DD.`);
    this.name = 'InvalidDayKeyError';
  }
}

export function isValidDayKey(value: string): boolean {
  const match = DAY_KEY_PATTERN.exec(value);
  if (!match) return false;
  const [, y, m, d] = match;
  const year = Number(y);
  const month = Number(m);
  const day = Number(d);
  if (month < 1 || month > 12 || day < 1 || day > 31) return false;
  // Reject the likes of 2026-02-31.
  const probe = new Date(Date.UTC(year, month - 1, day));
  return (
    probe.getUTCFullYear() === year &&
    probe.getUTCMonth() === month - 1 &&
    probe.getUTCDate() === day
  );
}

/** Parses a day key into the UTC-midnight instant a `DATE` column round-trips. */
export function dayKeyToDate(value: string): Date {
  if (!isValidDayKey(value)) throw new InvalidDayKeyError(value);
  const match = DAY_KEY_PATTERN.exec(value);
  /* istanbul ignore next -- guarded by isValidDayKey above */
  if (!match) throw new InvalidDayKeyError(value);
  const [, y, m, d] = match;
  return new Date(Date.UTC(Number(y), Number(m) - 1, Number(d)));
}

/** Formats a `DATE`-backed value back into a day key, reading UTC components. */
export function dateToDayKey(value: Date): string {
  const year = value.getUTCFullYear().toString().padStart(4, '0');
  const month = (value.getUTCMonth() + 1).toString().padStart(2, '0');
  const day = value.getUTCDate().toString().padStart(2, '0');
  return `${year}-${month}-${day}`;
}

/** Inclusive comparison used by the suggested-sequence date window. */
export function isDayWithin(day: Date, start: Date, end: Date): boolean {
  const d = day.getTime();
  return d >= start.getTime() && d <= end.getTime();
}

/**
 * ISO-8601 weekday (1=Mon .. 7=Sun) of a day key, matching Dart's
 * `DateTime.weekday` -- the numbering `Employee.workingDays` uses.
 */
export function dayKeyWeekday(value: string): number {
  const date = dayKeyToDate(value);
  const jsDay = date.getUTCDay(); // 0=Sun .. 6=Sat
  return jsDay === 0 ? 7 : jsDay;
}
