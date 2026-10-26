import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';

/// HTTPS path for call-critical `callInvites` transitions.
///
/// The iOS Firestore client can wedge its only worker queue on a
/// connectivity change (firebase-ios-sdk#12522), after which every client
/// transaction hangs. Cloud Functions callables use a separate HTTPS stack,
/// so accept, decline, stage, and terminal transitions go through the
/// `callInviteTransition` callable first and only fall back to the Firestore
/// transaction when this returns null.
abstract class CallInviteSignaling {
  /// Runs one server-side transition. Returns the server result, or null when
  /// the HTTPS path is unavailable (not deployed, offline, timed out, or
  /// rejected) so the caller uses its Firestore fallback.
  Future<Map<String, dynamic>?> transition(
    String action,
    Map<String, Object?> data,
  );
}

class FirebaseCallInviteSignaling implements CallInviteSignaling {
  FirebaseCallInviteSignaling({
    FirebaseFunctions? functions,
    this.timeout = const Duration(seconds: 6),
  }) : _functions = functions;

  static const String callableName = 'callInviteTransition';

  final FirebaseFunctions? _functions;
  final Duration timeout;

  @override
  Future<Map<String, dynamic>?> transition(
    String action,
    Map<String, Object?> data,
  ) async {
    try {
      final callable =
          (_functions ?? FirebaseFunctions.instanceFor(region: 'us-central1'))
              .httpsCallable(
        callableName,
        options: HttpsCallableOptions(timeout: timeout),
      );
      final result = await callable
          .call<dynamic>(<String, Object?>{'action': action, ...data}).timeout(
              timeout + const Duration(seconds: 1));
      final value = result.data;
      if (value is Map) {
        return value.map((key, item) => MapEntry(key.toString(), item));
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
