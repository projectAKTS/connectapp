import 'dart:convert';

final RegExp _callkitUuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

bool isValidCallkitId(String value) =>
    _callkitUuidPattern.hasMatch(value.trim());

String normalizeCallkitId({
  required String rawId,
  String fallback = '',
}) {
  final trimmedRaw = rawId.trim();
  if (isValidCallkitId(trimmedRaw)) return trimmedRaw.toLowerCase();

  final trimmedFallback = fallback.trim();
  if (isValidCallkitId(trimmedFallback)) return trimmedFallback.toLowerCase();

  final source = trimmedRaw.isNotEmpty
      ? trimmedRaw
      : (trimmedFallback.isNotEmpty ? trimmedFallback : '0');
  final baseHex = utf8
      .encode(source)
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();

  var hex = baseHex;
  while (hex.length < 32) {
    hex += baseHex;
  }
  hex = hex.substring(0, 32);

  hex = '${hex.substring(0, 12)}4${hex.substring(13, 16)}8${hex.substring(17)}';

  return '${hex.substring(0, 8)}-'
      '${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-'
      '${hex.substring(16, 20)}-'
      '${hex.substring(20, 32)}';
}
