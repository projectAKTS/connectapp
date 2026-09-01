import 'package:flutter_test/flutter_test.dart';

import 'package:connect_app/call_v2/diagnostics/call_v2_physical_diagnostic_ledger.dart';

class _FakeNativeBridge implements CallV2NativeDiagnosticBridge {
  Object? timeline;
  bool acknowledgeResult = true;
  final List<String> acknowledged = <String>[];

  @override
  Future<bool> acknowledgeRouteOwnership(String exactNativeKey) async {
    acknowledged.add(exactNativeKey);
    return acknowledgeResult;
  }

  @override
  Future<Object?> loadSafeTimeline() async => timeline;
}

void main() {
  test('timeline is monotonic, bounded to two calls, and safe', () {
    var now = DateTime.fromMillisecondsSinceEpoch(1000);
    final ledger = CallV2PhysicalDiagnosticLedger(now: () => now);

    for (var call = 1; call <= 3; call += 1) {
      final exactKey = 'unsafe-exact-key-$call';
      ledger.beginAcceptedNativeCall(
        exactNativeKey: exactKey,
        nativeOrdinal: call,
        startedAtEpochMilliseconds: now.millisecondsSinceEpoch,
      );
      now = now.add(const Duration(milliseconds: 7));
      ledger.record(CallV2PhysicalDiagnosticStage.flutterAcceptBridgeReceived);
      now = now.add(const Duration(milliseconds: 11));
      ledger.record(CallV2PhysicalDiagnosticStage.routeAttemptStarted);
    }

    final timelines = ledger.safeTimelines();
    expect(timelines, hasLength(2));
    for (final timeline in timelines) {
      expect(
        timeline.entries.map((entry) => entry.sequence),
        orderedEquals(<int>[1, 2]),
      );
      expect(
        timeline.entries.map((entry) => entry.elapsedMilliseconds),
        orderedEquals(<int>[7, 18]),
      );
    }

    final report = ledger.buildSafeReport();
    expect(report, contains('CALL 1:'));
    expect(report, contains('CALL 2:'));
    expect(report, isNot(contains('unsafe-exact-key')));
    expect(report, isNot(contains('token')));
    expect(report, isNot(contains('channel')));
    expect(report, isNot(contains('uuid')));
    expect(report, isNot(contains('payload')));
  });

  test('native timeline merges without exposing private ownership values',
      () async {
    final bridge = _FakeNativeBridge()
      ..timeline = <String, Object>{
        'calls': <Object>[
          <String, Object>{
            'ordinal': 4,
            'startedAtEpochMilliseconds': 1000,
            'entries': <Object>[
              <String, Object>{
                'sequence': 1,
                'elapsedMilliseconds': 0,
                'stage': 'pushkitReceived',
              },
              <String, Object>{
                'sequence': 2,
                'elapsedMilliseconds': 20,
                'stage': 'nativeAcceptObserved',
              },
            ],
          },
        ],
        'nativeWatchActive': true,
        'routeOwnedAck': false,
        'nativeCallActive': true,
        'blockerCode': 'none',
      };
    final ledger = CallV2PhysicalDiagnosticLedger(nativeBridge: bridge);

    await ledger.refreshNativeTimeline();

    final report = ledger.buildSafeReport();
    expect(report, contains('01 pushkitReceived +0ms'));
    expect(report, contains('02 nativeAcceptObserved +20ms'));
    expect(report, contains('nativeWatchActive=true'));
  });

  test(
      'route ownership acknowledgement uses exact key once but keeps it private',
      () async {
    final bridge = _FakeNativeBridge();
    final ledger = CallV2PhysicalDiagnosticLedger(nativeBridge: bridge);
    ledger.beginAcceptedNativeCall(
      exactNativeKey: 'private-native-key',
      nativeOrdinal: 1,
    );
    ledger.record(CallV2PhysicalDiagnosticStage.routeOpened);

    expect(await ledger.acknowledgeRouteOpened('private-native-key'), isTrue);
    expect(bridge.acknowledged, <String>['private-native-key']);
    expect(ledger.safeState()['routeOwnedAck'], isTrue);
    expect(ledger.safeState()['nativeWatchActive'], isFalse);
    expect(ledger.buildSafeReport(), isNot(contains('private-native-key')));
  });

  test('navigator-unavailable equivalent does not acknowledge native ownership',
      () async {
    final bridge = _FakeNativeBridge();
    final ledger = CallV2PhysicalDiagnosticLedger(nativeBridge: bridge);
    ledger.beginAcceptedNativeCall(
      exactNativeKey: 'private-native-key',
      nativeOrdinal: 1,
    );
    ledger.record(CallV2PhysicalDiagnosticStage.routeAttemptStarted);

    expect(bridge.acknowledged, isEmpty);
    expect(ledger.safeState()['routeOwnedAck'], isFalse);
    expect(ledger.safeState()['nativeWatchActive'], isTrue);
  });

  test('late route acknowledgement is controlled after native timeout state',
      () async {
    final bridge = _FakeNativeBridge()..acknowledgeResult = false;
    final ledger = CallV2PhysicalDiagnosticLedger(nativeBridge: bridge);
    ledger.beginAcceptedNativeCall(
      exactNativeKey: 'private-native-key',
      nativeOrdinal: 1,
    );
    ledger.record(CallV2PhysicalDiagnosticStage.nativeSafetyTimeoutFired);
    ledger.record(CallV2PhysicalDiagnosticStage.nativeCallEndVerified);

    expect(await ledger.acknowledgeRouteOpened('private-native-key'), isFalse);
    expect(ledger.safeState()['routeOwnedAck'], isFalse);
    expect(ledger.safeState()['nativeCallActive'], isFalse);
    expect(
      ledger.safeState()['blockerCode'],
      'native_route_timeout',
    );
  });
}
