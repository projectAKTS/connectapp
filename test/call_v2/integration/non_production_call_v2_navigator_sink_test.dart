import 'dart:async';
import 'dart:io';

import 'package:connect_app/call_v2/call_v2_api.dart';
import 'package:connect_app/call_v2/integration/call_v2_route_factory.dart';
import 'package:connect_app/call_v2/integration/non_production/non_production_call_v2_navigator_route_sink.dart';
import 'package:connect_app/call_v2/integration/non_production_call_v2_route_factory.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('construction and isolation', () {
    testWidgets('constructor has no navigation side effect', (tester) async {
      final key = GlobalKey<NavigatorState>();
      final observer = _RecordingNavigatorObserver();

      await _pumpHost(tester, key: key, observer: observer);

      final sink = NonProductionCallV2NavigatorRouteSink.fromNavigatorKey(
        navigatorKey: key,
      );

      expect(sink.ownedRouteCount, 0);
      expect(observer.events, isEmpty);
      expect(find.text(_hostText), findsOneWidget);
    });

    test('source stays isolated from real app and platform dependencies', () {
      final source = _sinkSource();

      for (final forbidden in <String>[
        'main.dart',
        'app_router',
        'CallV2ProductionComposition',
        'ProductionCallV2StartupBridge',
        'CallV2Runtime',
        'Firebase',
        'Firestore',
        'Rtc',
        'Agora',
        'Permission',
        'GetIt',
        'Provider<',
        'static final NonProductionCallV2NavigatorRouteSink',
        'static NonProductionCallV2NavigatorRouteSink',
        'debugPrint',
        'print(',
        'settings.arguments',
        'arguments',
      ]) {
        expect(source.contains(forbidden), isFalse, reason: forbidden);
      }

      expect(source.contains('GlobalKey<NavigatorState>'), isTrue);
      expect(source.contains('navigatorKey.currentState'), isTrue);
    });
  });

  group('navigator availability', () {
    test('missing Navigator returns controlled unavailable without buffering',
        () async {
      final key = GlobalKey<NavigatorState>();
      final sink = NonProductionCallV2NavigatorRouteSink.fromNavigatorKey(
        navigatorKey: key,
      );

      await expectLater(
        sink.open(_route(const CallV2RouteDestination.connecting())),
        throwsA(_clientError(CallV2ClientErrorCode.unavailable)),
      );

      expect(sink.ownedRouteCount, 0);
    });

    testWidgets('missing Navigator performs no retry after host appears',
        (tester) async {
      final key = GlobalKey<NavigatorState>();
      final observer = _RecordingNavigatorObserver();
      final sink = NonProductionCallV2NavigatorRouteSink.fromNavigatorKey(
        navigatorKey: key,
      );

      await expectLater(
        sink.open(_route(const CallV2RouteDestination.ready())),
        throwsA(_clientError(CallV2ClientErrorCode.unavailable)),
      );

      await _pumpHost(tester, key: key, observer: observer);
      await tester.pumpAndSettle();

      expect(find.text('Call V2 ready placeholder'), findsNothing);
      expect(observer.events, isEmpty);
    });

    testWidgets('disposed Navigator fails safely with controlled unavailable',
        (tester) async {
      final key = GlobalKey<NavigatorState>();
      final sink = NonProductionCallV2NavigatorRouteSink.fromNavigatorKey(
        navigatorKey: key,
      );

      await _pumpHost(tester, key: key);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();

      await expectLater(
        sink.open(_route(const CallV2RouteDestination.connecting())),
        throwsA(_clientError(CallV2ClientErrorCode.unavailable)),
      );
    });
  });

  group('open behavior', () {
    testWidgets('connecting, ready, and failure routes push once',
        (tester) async {
      final key = GlobalKey<NavigatorState>();
      final observer = _RecordingNavigatorObserver();
      final sink = NonProductionCallV2NavigatorRouteSink.fromNavigatorKey(
        navigatorKey: key,
      );

      await _pumpHost(tester, key: key, observer: observer);

      await sink.open(_route(const CallV2RouteDestination.connecting()));
      await tester.pumpAndSettle();
      expect(find.text('Call V2 connecting placeholder'), findsOneWidget);

      await sink.open(_route(const CallV2RouteDestination.ready()));
      await tester.pumpAndSettle();
      expect(find.text('Call V2 ready placeholder'), findsOneWidget);

      await sink.open(
        _route(
          const CallV2RouteDestination.controlledFailure(
            errorCode: CallV2ClientErrorCode.unavailable,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Call V2 unavailable'), findsOneWidget);

      expect(observer.pushedNames, <String>[
        CallV2RouteFactoryNames.connecting,
        CallV2RouteFactoryNames.ready,
        CallV2RouteFactoryNames.controlledFailure,
      ]);
      expect(sink.ownedRouteCount, 3);
    });

    testWidgets(
        'concurrent opens remain ordered and duplicates remain separate',
        (tester) async {
      final key = GlobalKey<NavigatorState>();
      final observer = _RecordingNavigatorObserver();
      final sink = NonProductionCallV2NavigatorRouteSink.fromNavigatorKey(
        navigatorKey: key,
      );

      await _pumpHost(tester, key: key, observer: observer);

      await Future.wait(<Future<void>>[
        sink.open(_route(const CallV2RouteDestination.connecting())),
        sink.open(_route(const CallV2RouteDestination.connecting())),
        sink.open(_route(const CallV2RouteDestination.ready())),
      ]);
      await tester.pumpAndSettle();

      expect(observer.pushedNames, <String>[
        CallV2RouteFactoryNames.connecting,
        CallV2RouteFactoryNames.connecting,
        CallV2RouteFactoryNames.ready,
      ]);
      expect(sink.ownedRouteCount, 3);
    });

    testWidgets('route names remain identifier-free and arguments unused',
        (tester) async {
      final key = GlobalKey<NavigatorState>();
      final observer = _RecordingNavigatorObserver();
      final sink = NonProductionCallV2NavigatorRouteSink.fromNavigatorKey(
        navigatorKey: key,
      );

      await _pumpHost(tester, key: key, observer: observer);
      await sink.open(_route(const CallV2RouteDestination.ready()));
      await tester.pumpAndSettle();

      expect(observer.pushedArguments.single, isNull);
      for (final name in observer.pushedNames) {
        expect(name, isNot(contains('callId')));
        expect(name, isNot(contains('uid')));
        expect(name, isNot(contains('token')));
        expect(name, isNot(contains('channel')));
        expect(name, isNot(contains(':')));
      }
    });
  });

  group('close behavior', () {
    testWidgets('close removes only owned routes and preserves host/root',
        (tester) async {
      final key = GlobalKey<NavigatorState>();
      final observer = _RecordingNavigatorObserver();
      final sink = NonProductionCallV2NavigatorRouteSink.fromNavigatorKey(
        navigatorKey: key,
      );

      await _pumpHost(tester, key: key, observer: observer);
      unawaited(key.currentState!.push<dynamic>(_unrelatedRoute()));
      await tester.pumpAndSettle();

      await sink.open(_route(const CallV2RouteDestination.connecting()));
      await sink.open(_route(const CallV2RouteDestination.ready()));
      await tester.pumpAndSettle();

      await sink.close();
      await tester.pumpAndSettle();

      expect(find.text(_hostText), findsNothing);
      expect(find.text(_unrelatedText), findsOneWidget);
      expect(find.text('Call V2 connecting placeholder'), findsNothing);
      expect(find.text('Call V2 ready placeholder'), findsNothing);
      expect(observer.removedNames, <String>[
        CallV2RouteFactoryNames.ready,
        CallV2RouteFactoryNames.connecting,
      ]);

      await key.currentState!.maybePop();
      await tester.pumpAndSettle();
      expect(find.text(_hostText), findsOneWidget);
    });

    testWidgets('close before open and repeated close are safe',
        (tester) async {
      final key = GlobalKey<NavigatorState>();
      final sink = NonProductionCallV2NavigatorRouteSink.fromNavigatorKey(
        navigatorKey: key,
      );

      await _pumpHost(tester, key: key);

      await sink.close();
      await sink.close();
      await tester.pumpAndSettle();

      expect(find.text(_hostText), findsOneWidget);
      expect(sink.ownedRouteCount, 0);
    });

    testWidgets('close follows pending opens deterministically',
        (tester) async {
      final key = GlobalKey<NavigatorState>();
      final sink = NonProductionCallV2NavigatorRouteSink.fromNavigatorKey(
        navigatorKey: key,
      );

      await _pumpHost(tester, key: key);

      final open = sink.open(_route(const CallV2RouteDestination.connecting()));
      final close = sink.close();
      await Future.wait(<Future<void>>[open, close]);
      await tester.pumpAndSettle();

      expect(find.text(_hostText), findsOneWidget);
      expect(find.text('Call V2 connecting placeholder'), findsNothing);
      expect(sink.ownedRouteCount, 0);
    });
  });

  group('dispose and races', () {
    testWidgets('dispose is idempotent and cleans owned routes safely',
        (tester) async {
      final key = GlobalKey<NavigatorState>();
      final sink = NonProductionCallV2NavigatorRouteSink.fromNavigatorKey(
        navigatorKey: key,
      );

      await _pumpHost(tester, key: key);
      await sink.open(_route(const CallV2RouteDestination.ready()));
      await tester.pumpAndSettle();
      expect(find.text('Call V2 ready placeholder'), findsOneWidget);

      await sink.dispose();
      await sink.dispose();
      await tester.pumpAndSettle();

      expect(find.text(_hostText), findsOneWidget);
      expect(find.text('Call V2 ready placeholder'), findsNothing);
      expect(sink.isDisposed, isTrue);
      expect(sink.ownedRouteCount, 0);
    });

    testWidgets('open after dispose rejects and queued open is not pushed',
        (tester) async {
      final key = GlobalKey<NavigatorState>();
      final observer = _RecordingNavigatorObserver();
      final sink = NonProductionCallV2NavigatorRouteSink.fromNavigatorKey(
        navigatorKey: key,
      );

      await _pumpHost(tester, key: key, observer: observer);

      final open = sink.open(_route(const CallV2RouteDestination.connecting()));
      final dispose = sink.dispose();

      await expectLater(
        open,
        throwsA(_clientError(CallV2ClientErrorCode.rejected)),
      );
      await dispose;
      await tester.pumpAndSettle();

      expect(observer.pushedNames, isEmpty);
      expect(find.text('Call V2 connecting placeholder'), findsNothing);

      await expectLater(
        sink.open(_route(const CallV2RouteDestination.ready())),
        throwsA(_clientError(CallV2ClientErrorCode.rejected)),
      );
    });

    testWidgets('close after dispose safely no-ops and host remains visible',
        (tester) async {
      final key = GlobalKey<NavigatorState>();
      final sink = NonProductionCallV2NavigatorRouteSink.fromNavigatorKey(
        navigatorKey: key,
      );

      await _pumpHost(tester, key: key);
      await sink.dispose();
      await sink.close();
      await tester.pumpAndSettle();

      expect(find.text(_hostText), findsOneWidget);
    });
  });
}

const _hostText = 'Call V2 test host';
const _unrelatedText = 'Unrelated test route';

Route<dynamic> _route(CallV2RouteDestination destination) {
  return const NonProductionCallV2RouteFactory().create(destination);
}

Route<dynamic> _unrelatedRoute() {
  return MaterialPageRoute<dynamic>(
    settings: const RouteSettings(name: '/unrelated'),
    builder: (_) => const Directionality(
      textDirection: TextDirection.ltr,
      child: Center(child: Text(_unrelatedText)),
    ),
  );
}

Future<void> _pumpHost(
  WidgetTester tester, {
  required GlobalKey<NavigatorState> key,
  NavigatorObserver? observer,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: key,
      navigatorObservers: observer == null
          ? const <NavigatorObserver>[]
          : <NavigatorObserver>[observer],
      home: const Scaffold(body: Center(child: Text(_hostText))),
    ),
  );
  await tester.pumpAndSettle();
}

Matcher _clientError(CallV2ClientErrorCode code) {
  return isA<CallV2ClientError>().having((error) => error.code, 'code', code);
}

String _sinkSource() {
  return File(
    'lib/call_v2/integration/non_production/'
    'non_production_call_v2_navigator_route_sink.dart',
  ).readAsStringSync();
}

final class _RecordingNavigatorObserver extends NavigatorObserver {
  final List<String> events = <String>[];
  final List<String?> pushedNames = <String?>[];
  final List<Object?> pushedArguments = <Object?>[];
  final List<String?> removedNames = <String?>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final name = route.settings.name;
    if (name != '/') {
      pushedNames.add(name);
      pushedArguments.add(route.settings.arguments);
      events.add('push:$name');
    }
    super.didPush(route, previousRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final name = route.settings.name;
    removedNames.add(name);
    events.add('remove:$name');
    super.didRemove(route, previousRoute);
  }
}
