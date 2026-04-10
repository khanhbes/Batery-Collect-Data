// Loose type conversion helpers that accept `num`, `String`, `bool`, or `null`
// without throwing. Used across telemetry events, model persistence, and
// stop-payloads where the runtime type may be inconsistent.

int? toIntLoose(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) {
    final String t = value.trim();
    if (t.isEmpty) return null;
    return int.tryParse(t) ?? double.tryParse(t)?.toInt();
  }
  return null;
}

double? toDoubleLoose(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) {
    final String t = value.trim();
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }
  return null;
}

bool? toBoolLoose(dynamic value) {
  if (value == null) return null;
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final String n = value.trim().toLowerCase();
    if (n == 'true' || n == '1' || n == 'yes') return true;
    if (n == 'false' || n == '0' || n == 'no' || n.isEmpty) return false;
  }
  return null;
}

String toStringLoose(dynamic value, {String fallback = ''}) {
  if (value == null) return fallback;
  if (value is String) return value;
  return value.toString();
}
