import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// This app installation's stable push id: the
/// `users/{uid}/pushInstallations/{id}` document id, and the id the server
/// records as `acceptedInstallationId` when this device answers a call.
///
/// Stored in the application support directory, so the background
/// messaging isolate reads the same value as the app.
class PushInstallationId {
  PushInstallationId._();

  static const String fileName = 'helperly_push_installation_id';

  static String? _cached;

  @visibleForTesting
  static void debugSetForTest(String? id) => _cached = id;

  static bool isValid(String value) =>
      RegExp(r'^[A-Za-z0-9_-]{8,80}$').hasMatch(value.trim());

  /// The stored id, created on first use. If storage fails, a new id is
  /// used for this process only.
  static Future<String> read() async {
    final cached = _cached?.trim();
    if (cached != null && cached.isNotEmpty) return cached;
    try {
      final dir = await getApplicationSupportDirectory();
      final file = File('${dir.path}/$fileName');
      if (await file.exists()) {
        final existing = (await file.readAsString()).trim();
        if (isValid(existing)) {
          _cached = existing;
          return existing;
        }
      }
      final generated = const Uuid().v4();
      await file.writeAsString(generated, flush: true);
      _cached = generated;
      return generated;
    } catch (_) {
      final generated = const Uuid().v4();
      _cached = generated;
      return generated;
    }
  }
}
