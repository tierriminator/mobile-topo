/// Formats [value] with [decimals] places, or else with up to three places
/// and without trailing zeros
String formatNumber(num value, {int? decimals}) {
  if (decimals != null) return value.toStringAsFixed(decimals);
  final trimmed = value.toStringAsFixed(3).replaceFirst(RegExp(r'\.?0+$'), '');
  return trimmed == '-0' ? '0' : trimmed;
}
