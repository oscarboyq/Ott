/// Robust parsing helpers for JSON deserialization from Supabase / HTTP APIs.
/// Prevents runtime TypeErrors caused by unexpected number types (int vs double),
/// nulls, strings, or boolean representations in web & SQL responses.
library;

int parseIntSafe(dynamic value, [int defaultValue = 0]) {
  if (value == null) return defaultValue;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? defaultValue;
  return defaultValue;
}

double parseDoubleSafe(dynamic value, [double defaultValue = 0.0]) {
  if (value == null) return defaultValue;
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? defaultValue;
  return defaultValue;
}

bool parseBoolSafe(dynamic value, [bool defaultValue = false]) {
  if (value == null) return defaultValue;
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final lower = value.trim().toLowerCase();
    if (lower == 'true' || lower == '1' || lower == 'yes') return true;
    if (lower == 'false' || lower == '0' || lower == 'no') return false;
  }
  return defaultValue;
}

DateTime parseDateTimeSafe(dynamic value, [DateTime? fallback]) {
  final def = fallback ?? DateTime.now();
  if (value == null) return def;
  if (value is DateTime) return value;
  if (value is String) {
    return DateTime.tryParse(value) ?? def;
  }
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  return def;
}

DateTime? parseDateTimeNullableSafe(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String) {
    return DateTime.tryParse(value);
  }
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  return null;
}

List<String> parseStringListSafe(dynamic value) {
  if (value == null) return const [];
  if (value is List) {
    return value
        .where((e) => e != null)
        .map((e) => e.toString())
        .toList();
  }
  if (value is String) {
    if (value.trim().isEmpty) return const [];
    return value
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }
  return const [];
}
