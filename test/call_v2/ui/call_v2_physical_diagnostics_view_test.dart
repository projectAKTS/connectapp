import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:connect_app/call_v2/diagnostics/call_v2_physical_diagnostic_ledger.dart';
import 'package:connect_app/call_v2/diagnostics/call_v2_physical_diagnostics_view.dart';

class _FakeNativeBridge implements CallV2NativeDiagnosticBridge {
  Object? timeline;
  int loadCount = 0;

  @override
  Future<bool> acknowledgeRouteOwnership(String exactNativeKey) async => true;

  @override
  Future<Object?> loadSafeTimeline() async {
    loadCount += 1;
    return timeline;
  }
}

void main() {
  testWidgets('diagnostics overlay is absent while developer gate is disabled',
      (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigatorKey,
      home: CallV2PhysicalDiagnosticsOverlay(
        enabled: false,
        navigatorKey: navigatorKey,
        child: const Text('home'),
      ),
    ));

    expect(find.byKey(const ValueKey<String>('call-v2-diagnostics-open')),
        findsNothing);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('developer-gated view exposes only compact safe report',
      (tester) async {
    final ledger = CallV2PhysicalDiagnosticLedger(
      nativeBridge: _FakeNativeBridge(),
    );
    ledger.beginAcceptedNativeCall(
      exactNativeKey: 'private-native-key',
      nativeOrdinal: 1,
    );
    ledger.record(CallV2PhysicalDiagnosticStage.flutterAcceptBridgeReceived);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: CallV2PhysicalDiagnosticsView(ledger: ledger)),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Call V2 diagnostics'), findsOneWidget);
    final report = tester.widget<SelectableText>(
      find.byKey(const ValueKey<String>('call-v2-diagnostics-report')),
    );
    expect(report.data, contains('flutterAcceptBridgeReceived'));
    expect(report.data, isNot(contains('private-native-key')));
    expect(find.byKey(const ValueKey<String>('call-v2-diagnostics-copy')),
        findsOneWidget);
  });

  testWidgets(
      'builder-mounted overlay opens through app navigator and copies refreshed native timeline',
      (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    final bridge = _FakeNativeBridge()
      ..timeline = _nativeTimeline(<String>['nativeSafetyWatchStarted']);
    final ledger = CallV2PhysicalDiagnosticLedger(nativeBridge: bridge);
    String? copiedReport;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copiedReport =
              (call.arguments as Map<Object?, Object?>)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });

    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigatorKey,
      builder: (context, child) => CallV2PhysicalDiagnosticsOverlay(
        enabled: true,
        navigatorKey: navigatorKey,
        ledger: ledger,
        child: child ?? const SizedBox.shrink(),
      ),
      home: const Scaffold(body: Text('home')),
    ));

    await tester.tap(
      find.byKey(const ValueKey<String>('call-v2-diagnostics-open')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Call V2 diagnostics'), findsOneWidget);
    expect(bridge.loadCount, 1);
    var report = tester.widget<SelectableText>(
      find.byKey(const ValueKey<String>('call-v2-diagnostics-report')),
    );
    expect(report.data, contains('nativeSafetyWatchStarted'));

    bridge.timeline = _nativeTimeline(<String>[
      'nativeSafetyWatchStarted',
      'nativeSafetyTimeoutFired',
    ]);
    await tester.tap(
      find.byKey(const ValueKey<String>('call-v2-diagnostics-copy')),
    );
    await tester.pumpAndSettle();

    expect(bridge.loadCount, 2);
    report = tester.widget<SelectableText>(
      find.byKey(const ValueKey<String>('call-v2-diagnostics-report')),
    );
    expect(report.data, contains('nativeSafetyTimeoutFired'));
    expect(copiedReport, contains('nativeSafetyTimeoutFired'));
    expect(copiedReport, isNot(contains('private-native-key')));
  });
}

Map<String, Object> _nativeTimeline(List<String> stages) => <String, Object>{
      'calls': <Object>[
        <String, Object>{
          'ordinal': 1,
          'startedAtEpochMilliseconds': 1000,
          'entries': <Object>[
            for (var index = 0; index < stages.length; index += 1)
              <String, Object>{
                'sequence': index + 1,
                'elapsedMilliseconds': index * 20,
                'stage': stages[index],
              },
          ],
        },
      ],
      'nativeWatchActive': true,
      'routeOwnedAck': false,
      'nativeCallActive': true,
      'blockerCode': 'none',
    };
