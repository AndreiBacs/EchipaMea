import {
  InvalidDayKeyError,
  dateToDayKey,
  dayKeyToDate,
  dayKeyWeekday,
  isDayWithin,
  isValidDayKey,
} from './day-key';

describe('isValidDayKey', () => {
  it('accepts a well-formed key', () => {
    expect(isValidDayKey('2026-08-14')).toBe(true);
    expect(isValidDayKey('2024-02-29')).toBe(true); // leap year
  });

  it('rejects malformed shapes', () => {
    expect(isValidDayKey('2026-8-14')).toBe(false);
    expect(isValidDayKey('14-08-2026')).toBe(false);
    expect(isValidDayKey('2026-08-14T00:00:00Z')).toBe(false);
    expect(isValidDayKey('')).toBe(false);
  });

  it('rejects dates that do not exist', () => {
    expect(isValidDayKey('2026-02-30')).toBe(false);
    expect(isValidDayKey('2026-13-01')).toBe(false);
    expect(isValidDayKey('2025-02-29')).toBe(false); // not a leap year
  });
});

describe('dayKeyToDate / dateToDayKey', () => {
  it('round-trips losslessly', () => {
    for (const key of ['2026-01-01', '2026-08-14', '2026-12-31', '2024-02-29']) {
      expect(dateToDayKey(dayKeyToDate(key))).toBe(key);
    }
  });

  it('anchors at UTC midnight so a DATE column round-trips', () => {
    const date = dayKeyToDate('2026-08-14');
    expect(date.toISOString()).toBe('2026-08-14T00:00:00.000Z');
  });

  it('throws on an invalid key', () => {
    expect(() => dayKeyToDate('nope')).toThrow(InvalidDayKeyError);
  });

  /**
   * The client computes its day key from local wall clock. If the server ever
   * reinterpreted that key in its own zone, a worker west of UTC would see the
   * previous day's schedule. Reading UTC components on both sides is what
   * prevents that.
   */
  it('does not shift the calendar date across timezones', () => {
    const key = '2026-08-14';
    const stored = dayKeyToDate(key);
    expect(dateToDayKey(stored)).toBe(key);
    expect(stored.getUTCDate()).toBe(14);
  });
});

describe('dayKeyWeekday', () => {
  it('uses ISO numbering, 1=Mon .. 7=Sun, matching Dart DateTime.weekday', () => {
    expect(dayKeyWeekday('2026-08-10')).toBe(1); // Monday
    expect(dayKeyWeekday('2026-08-14')).toBe(5); // Friday
    expect(dayKeyWeekday('2026-08-15')).toBe(6); // Saturday
    expect(dayKeyWeekday('2026-08-16')).toBe(7); // Sunday, not 0
  });
});

describe('isDayWithin', () => {
  const start = dayKeyToDate('2026-04-13');
  const end = dayKeyToDate('2026-04-16');

  it('is inclusive at both ends', () => {
    expect(isDayWithin(dayKeyToDate('2026-04-13'), start, end)).toBe(true);
    expect(isDayWithin(dayKeyToDate('2026-04-16'), start, end)).toBe(true);
  });

  it('excludes days outside the window', () => {
    expect(isDayWithin(dayKeyToDate('2026-04-12'), start, end)).toBe(false);
    expect(isDayWithin(dayKeyToDate('2026-04-17'), start, end)).toBe(false);
  });
});
