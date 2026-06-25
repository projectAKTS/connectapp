import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connect_app/services/helperly_test_runtime.dart';

import 'diagnostic_service.dart';

class FirestoreReadHelper {
  static const Duration defaultTimeout = Duration(seconds: 8);
  static const Duration cacheTimeout = Duration(seconds: 2);
  static const Duration networkRecoveryThrottle = Duration(seconds: 15);
  static const Duration hardNetworkRecoveryThrottle = Duration(seconds: 20);
  static DateTime? _lastNetworkRecoveryAt;
  static DateTime? _lastHardNetworkRecoveryAt;
  static int _consecutiveRecoverableErrors = 0;
  static bool _recoveryInFlight = false;

  static Future<void> recoverNetwork({
    String reason = 'manual',
    bool force = false,
  }) async {
    if (HelperlyTestRuntime.isEnabled) return;
    final now = DateTime.now();
    if (force) {
      final lastHard = _lastHardNetworkRecoveryAt;
      if (lastHard != null &&
          now.difference(lastHard) < hardNetworkRecoveryThrottle) {
        return;
      }
      _lastHardNetworkRecoveryAt = now;
    } else {
      final last = _lastNetworkRecoveryAt;
      if (last != null && now.difference(last) < networkRecoveryThrottle) {
        return;
      }
      _lastNetworkRecoveryAt = now;
    }

    if (_recoveryInFlight) {
      DiagnosticService.logSystem('firestore_recover_skipped', meta: {
        'reason': reason,
        'force': force,
        'recoveryInFlight': true,
      });
      return;
    }

    _recoveryInFlight = true;
    DiagnosticService.logSystem('firestore_recover_start', meta: {
      'reason': reason,
      'force': force,
      'destructiveReset': false,
    });
    unawaited(() async {
      try {
        // Do not call disableNetwork() as a recovery step. If enableNetwork()
        // later stalls, the app can remain offline until force quit.
        await HelperlyTestRuntime.firestore
            .enableNetwork()
            .timeout(const Duration(seconds: 3));
        DiagnosticService.logSystem('firestore_recover_done', meta: {
          'reason': reason,
          'force': force,
          'destructiveReset': false,
        });
      } catch (error) {
        DiagnosticService.logSystem('firestore_recover_error', meta: {
          'reason': reason,
          'force': force,
          'destructiveReset': false,
          'error': '$error',
        });
      } finally {
        _recoveryInFlight = false;
      }
    }());
  }

  static Future<void> ensureNetworkEnabled({
    String reason = 'manual',
  }) async {
    if (HelperlyTestRuntime.isEnabled) return;
    try {
      await HelperlyTestRuntime.firestore
          .enableNetwork()
          .timeout(const Duration(seconds: 3));
      DiagnosticService.logSystem('firestore_enable_done', meta: {
        'reason': reason,
      });
    } catch (error) {
      DiagnosticService.logSystem('firestore_enable_error', meta: {
        'reason': reason,
        'error': '$error',
      });
    }
  }

  static bool isRecoverableError(Object error) {
    final text = error.toString().toLowerCase();
    return text.contains('unavailable') ||
        text.contains('deadline-exceeded') ||
        text.contains('timeout') ||
        text.contains('network');
  }

  static void _recoverIfUnavailable(Object error) {
    if (isRecoverableError(error)) {
      _consecutiveRecoverableErrors += 1;
      unawaited(recoverNetwork(
        reason: 'read_error',
        force: _consecutiveRecoverableErrors >= 2,
      ));
    }
  }

  static void _markReadSuccess() {
    _consecutiveRecoverableErrors = 0;
  }

  static Future<DocumentSnapshot<Map<String, dynamic>>> getDoc(
    DocumentReference<Map<String, dynamic>> ref, {
    Duration timeout = defaultTimeout,
  }) async {
    if (HelperlyTestRuntime.isEnabled) {
      return ref.get();
    }
    try {
      final snap = await ref
          .get(const GetOptions(source: Source.serverAndCache))
          .timeout(timeout);
      _markReadSuccess();
      return snap;
    } catch (error) {
      _recoverIfUnavailable(error);
      try {
        final snap = await ref
            .get(const GetOptions(source: Source.cache))
            .timeout(cacheTimeout);
        _markReadSuccess();
        return snap;
      } catch (cacheError) {
        _recoverIfUnavailable(cacheError);
        rethrow;
      }
    }
  }

  static Future<QuerySnapshot<Map<String, dynamic>>> getQuery(
    Query<Map<String, dynamic>> query, {
    Duration timeout = defaultTimeout,
  }) async {
    if (HelperlyTestRuntime.isEnabled) {
      return query.get();
    }
    try {
      final snap = await query
          .get(const GetOptions(source: Source.serverAndCache))
          .timeout(timeout);
      _markReadSuccess();
      return snap;
    } catch (error) {
      _recoverIfUnavailable(error);
      try {
        final snap = await query
            .get(const GetOptions(source: Source.cache))
            .timeout(cacheTimeout);
        _markReadSuccess();
        return snap;
      } catch (cacheError) {
        _recoverIfUnavailable(cacheError);
        rethrow;
      }
    }
  }
}
