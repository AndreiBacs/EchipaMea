/**
 * Dart's `String.compareTo` orders by UTF-16 code unit, and so does a plain JS
 * `<`. `localeCompare` would NOT match -- it would sort "Ș" next to "S" and
 * reorder Romanian names relative to the app.
 *
 * Anywhere the server reproduces an ordering the Flutter UI also computes --
 * phase names in a daily sequence, project names in a worker's job list -- it
 * has to use this, or the same list renders in two different orders depending
 * on whether it came from the server or from local state.
 */
export function byCodeUnit(a: string, b: string): number {
  if (a === b) return 0;
  return a < b ? -1 : 1;
}
