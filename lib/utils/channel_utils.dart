// lib/utils/channel_utils.dart
library channel_utils;

/// Generate a safe, short Agora channel name (<= 64 chars).
String generateChannelName(String uid1, String uid2) {
  String clean(String s) => s.replaceAll(RegExp(r'[^A-Za-z0-9_]'), '');

  final a = clean(uid1);
  final b = clean(uid2);
  final pair = [a, b]..sort();

  final sa = pair[0].length > 12 ? pair[0].substring(0, 12) : pair[0];
  final sb = pair[1].length > 12 ? pair[1].substring(0, 12) : pair[1];

  // short, unique-ish suffix
  final ts = DateTime.now().millisecondsSinceEpoch.toRadixString(36);

  var name = 'c_${sa}_${sb}_$ts';
  if (name.length > 64) name = name.substring(0, 64);
  return name;
}
