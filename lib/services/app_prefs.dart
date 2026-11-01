import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Small per-device settings (app language, usage statistics consent).
///
/// Stored as one JSON file in the application support directory, the same
/// way [PushInstallationId] is stored, so no extra plugin is needed. Read
/// once at startup, alongside Firebase initialization; writes are
/// best-effort. Nothing here is personal data or leaves the device.
class AppPrefs {
  AppPrefs._();

  static const String fileName = 'helperly_app_prefs.json';

  static Map<String, Object?> _values = {};
  static bool _loaded = false;

  @visibleForTesting
  static void debugSetForTest(Map<String, Object?> values) {
    _values = Map.of(values);
    _loaded = true;
  }

  @visibleForTesting
  static void debugReset() {
    _values = {};
    _loaded = false;
  }

  static Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$fileName');
  }

  /// Loads the stored values. A missing or broken file means defaults.
  static Future<void> load() async {
    if (_loaded) return;
    try {
      final file = await _file();
      if (await file.exists()) {
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is Map) {
          _values = decoded.map((k, v) => MapEntry('$k', v));
        }
      }
    } catch (_) {
      _values = {};
    }
    _loaded = true;
  }

  static String? getString(String key) {
    final v = _values[key];
    return v is String ? v : null;
  }

  static bool? getBool(String key) {
    final v = _values[key];
    return v is bool ? v : null;
  }

  /// Sets or, with null, removes [key], then saves.
  static Future<void> set(String key, Object? value) async {
    if (value == null) {
      _values.remove(key);
    } else {
      _values[key] = value;
    }
    try {
      final file = await _file();
      await file.writeAsString(jsonEncode(_values), flush: true);
    } catch (_) {
      // Kept in memory for this session.
    }
  }
}
