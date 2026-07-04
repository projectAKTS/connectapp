import 'package:connect_app/call_v2/call_v2_api.dart';
import 'package:connect_app/call_v2/design/call_v2_production_failure_matrix.dart';
import 'package:connect_app/call_v2/design/call_v2_production_lifecycle_design.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('failure matrix covers every required failure exactly once', () {
    final matrix = callV2ProductionFailureMatrix;

    expect(
      matrix.entries.map((entry) => entry.failure).toSet(),
      CallV2ProductionFailure.values.toSet(),
    );
    for (final failure in CallV2ProductionFailure.values) {
      expect(
        matrix.entries.where((entry) => entry.failure == failure),
        hasLength(1),
      );
    }
  });

  test('each failure maps to controlled error, cleanup, retry, and event', () {
    for (final entry in callV2ProductionFailureMatrix.entries) {
      expect(CallV2ClientErrorCode.values, contains(entry.errorCode));
      expect(
          CallV2ProductionCleanupPolicy.values, contains(entry.cleanupPolicy));
      expect(CallV2ProductionRetryPolicy.values, contains(entry.retryPolicy));
      expect(CallV2ProductionObservabilityEvent.values,
          contains(entry.observabilityEvent));
      expect(entry.rawDetailsSuppressed, isTrue);
      expect(entry.toString(), isNot(contains('Exception:')));
      expect(entry.toString(), isNot(contains('StackTrace')));
    }
  });

  test('self-call and duplicate launch are explicitly rejected', () {
    final selfCall = callV2ProductionFailureMatrix
        .entryFor(CallV2ProductionFailure.selfCallAttempt);
    final duplicate = callV2ProductionFailureMatrix
        .entryFor(CallV2ProductionFailure.duplicateLaunch);

    expect(selfCall.errorCode, CallV2ClientErrorCode.rejected);
    expect(selfCall.retryPolicy, CallV2ProductionRetryPolicy.never);
    expect(selfCall.rawDetailsSuppressed, isTrue);
    expect(duplicate.errorCode, CallV2ClientErrorCode.rejected);
    expect(duplicate.retryPolicy, CallV2ProductionRetryPolicy.sameRequestOnly);
  });

  test('recoverable failures use typed retry policies only', () {
    final recoverable = <CallV2ProductionFailure>{
      CallV2ProductionFailure.appCheckUnavailable,
      CallV2ProductionFailure.backendUnavailable,
      CallV2ProductionFailure.networkInterruption,
      CallV2ProductionFailure.credentialExpiry,
      CallV2ProductionFailure.routeSinkUnavailable,
    };

    for (final failure in recoverable) {
      final entry = callV2ProductionFailureMatrix.entryFor(failure);
      expect(
        entry.retryPolicy,
        isNot(CallV2ProductionRetryPolicy.never),
        reason: failure.name,
      );
    }
  });

  test('failure debug data contains no raw operational details', () {
    final text = callV2ProductionFailureMatrix.toString();

    for (final forbidden in <String>[
      'uid_',
      'call_',
      'participant_',
      'Bearer ',
      'stack:',
      'headers',
      'providerResponse',
    ]) {
      expect(text.contains(forbidden), isFalse, reason: forbidden);
    }
  });
}
