/// A calendar day as `YYYY-MM-DD`, the form the API uses for dates without a
/// time (phase windows, sequence days).
String dayKey(DateTime day) {
  final m = day.month.toString().padLeft(2, '0');
  final d = day.day.toString().padLeft(2, '0');
  return '${day.year.toString().padLeft(4, '0')}-$m-$d';
}

/// Parses a [dayKey] into local midnight of that day. A malformed key falls
/// back to today's part for each piece that does not parse.
DateTime dayFromKey(String key) {
  final now = DateTime.now();
  final parts = key.split('-');
  if (parts.length != 3) return DateTime(now.year, now.month, now.day);
  return DateTime(
    int.tryParse(parts[0]) ?? now.year,
    int.tryParse(parts[1]) ?? now.month,
    int.tryParse(parts[2]) ?? now.day,
  );
}
