import 'dart:io';

import 'package:connect_app/call_v2/call_v2_api.dart';
import 'package:connect_app/call_v2/integration/call_v2_route_factory.dart';
import 'package:connect_app/call_v2/integration/non_production/non_production_call_v2_connecting_placeholder.dart';
import 'package:connect_app/call_v2/integration/non_production/non_production_call_v2_failure_placeholder.dart';
import 'package:connect_app/call_v2/integration/non_production/non_production_call_v2_ready_placeholder.dart';
import 'package:connect_app/call_v2/integration/non_production_call_v2_route_factory.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('contract and construction', () {
    test('factory constructor has no side effects', () {
      const NonProductionCallV2RouteFactory();
    });

    test('destination model is typed and contains no arbitrary payload shapes',
        () {
      const destinations = <CallV2RouteDestination>[
        CallV2RouteDestination.connecting(),
        CallV2RouteDestination.ready(),
        CallV2RouteDestination.controlledFailure(
          errorCode: CallV2ClientErrorCode.unavailable,
        ),
      ];

      expect(destinations[0], isA<CallV2ConnectingRouteDestination>());
      expect(destinations[1], isA<CallV2ReadyRouteDestination>());
      expect(destinations[2], isA<CallV2ControlledFailureRouteDestination>());

      final source = _read(
        'lib/call_v2/integration/call_v2_route_factory.dart',
      );
      for (final forbidden in <String>[
        'String call',
        'String uid',
        'Map<',
        'Object? payload',
        'dynamic payload',
        'Exception',
        'StackTrace',
        'token',
        'channel',
        'Firestore',
        'Rtc',
      ]) {
        expect(source.contains(forbidden), isFalse, reason: forbidden);
      }
    });

    test('factory source contains no live services or registration path', () {
      final source = _factorySource();

      for (final forbidden in <String>[
        'Firebase',
        'FirebaseAuth',
        'FirebaseAppCheck',
        'FirebaseFirestore',
        'FirebaseFunctions',
        'Permission.',
        'requestPermission',
        'RtcEngine',
        'Agora',
        'CallV2ProductionComposition',
        'ProductionCallV2StartupBridge',
        'ProductionCallV2UiCoordinator',
        'CallV2Runtime(',
        'static final NonProductionCallV2RouteFactory',
        'static NonProductionCallV2RouteFactory',
        'GetIt',
        'Provider<',
        'registerSingleton',
        'initializeCallV2AppIntegration',
      ]) {
        expect(source.contains(forbidden), isFalse, reason: forbidden);
      }
    });

    test('route names are identifier-free', () {
      expect(CallV2RouteFactoryNames.connecting, '/call-v2/connecting');
      expect(CallV2RouteFactoryNames.ready, '/call-v2/ready');
      expect(CallV2RouteFactoryNames.controlledFailure, '/call-v2/unavailable');

      for (final name in <String>[
        CallV2RouteFactoryNames.connecting,
        CallV2RouteFactoryNames.ready,
        CallV2RouteFactoryNames.controlledFailure,
      ]) {
        expect(name, isNot(contains('uid')));
        expect(name, isNot(contains('callId')));
        expect(name, isNot(contains('token')));
        expect(name, isNot(contains(':')));
      }
    });
  });

  group('route construction', () {
    testWidgets('connecting destination creates one safe placeholder route',
        (tester) async {
      final route = const NonProductionCallV2RouteFactory().create(
        const CallV2RouteDestination.connecting(),
      );

      expect(route.settings.name, CallV2RouteFactoryNames.connecting);
      expect(route.settings.arguments, isNull);

      await _pumpRoute(tester, route);

      expect(find.byType(NonProductionCallV2ConnectingPlaceholder), findsOne);
      expect(find.byType(NonProductionCallV2ReadyPlaceholder), findsNothing);
      expect(find.byType(NonProductionCallV2FailurePlaceholder), findsNothing);
      expect(find.text('Call V2 connecting placeholder'), findsOneWidget);
    });

    testWidgets('ready destination creates one safe placeholder route',
        (tester) async {
      final route = const NonProductionCallV2RouteFactory().create(
        const CallV2RouteDestination.ready(),
      );

      expect(route.settings.name, CallV2RouteFactoryNames.ready);
      expect(route.settings.arguments, isNull);

      await _pumpRoute(tester, route);

      expect(
          find.byType(NonProductionCallV2ConnectingPlaceholder), findsNothing);
      expect(find.byType(NonProductionCallV2ReadyPlaceholder), findsOne);
      expect(find.byType(NonProductionCallV2FailurePlaceholder), findsNothing);
      expect(find.text('Call V2 ready placeholder'), findsOneWidget);
    });

    testWidgets('controlled failure creates only generic failure placeholder',
        (tester) async {
      final route = const NonProductionCallV2RouteFactory().create(
        const CallV2RouteDestination.controlledFailure(
          errorCode: CallV2ClientErrorCode.unauthorized,
        ),
      );

      expect(route.settings.name, CallV2RouteFactoryNames.controlledFailure);
      expect(route.settings.arguments, isNull);

      await _pumpRoute(tester, route);

      expect(
          find.byType(NonProductionCallV2ConnectingPlaceholder), findsNothing);
      expect(find.byType(NonProductionCallV2ReadyPlaceholder), findsNothing);
      expect(find.byType(NonProductionCallV2FailurePlaceholder), findsOne);
      expect(find.text('Call V2 unavailable'), findsOneWidget);
      expect(find.textContaining('unauthorized'), findsNothing);
      expect(find.textContaining('Firebase'), findsNothing);
      expect(find.textContaining('Rtc'), findsNothing);
      expect(find.textContaining('StackTrace'), findsNothing);
    });

    test('external arguments are not processed or required', () {
      final source = _read(
        'lib/call_v2/integration/non_production_call_v2_route_factory.dart',
      );

      for (final forbidden in <String>[
        'settings.arguments',
        'arguments',
        'as Map',
        'Uri.parse',
        'Uri.tryParse',
        'debugPrint',
        'print(',
      ]) {
        expect(source.contains(forbidden), isFalse, reason: forbidden);
      }
    });

    test('repeated construction is side-effect free and does not start runtime',
        () {
      const factory = NonProductionCallV2RouteFactory();

      for (var index = 0; index < 10; index += 1) {
        final route = factory.create(const CallV2RouteDestination.connecting());
        expect(route.settings.name, CallV2RouteFactoryNames.connecting);
      }

      final source = _factorySource();
      for (final forbidden in <String>[
        'Navigator.',
        'push',
        'pop(',
        'CallV2Runtime(',
        'start(',
        'Timer(',
      ]) {
        expect(source.contains(forbidden), isFalse, reason: forbidden);
      }
    });
  });

  group('placeholder safety', () {
    test('placeholder sources expose no identifiers, controls, or services',
        () {
      final source = _placeholderSource();

      for (final forbidden in <String>[
        'callId',
        'uid',
        'participant',
        'token',
        'channel',
        'microphone',
        'camera',
        'Firebase',
        'Firestore',
        'Rtc',
        'Agora',
        'WidgetsBindingObserver',
        'Timer',
        'Navigator',
        'showDialog',
        'showModalBottomSheet',
        'Permission',
        'CallV2UiCoordinator',
        'CallV2Runtime',
      ]) {
        expect(source.contains(forbidden), isFalse, reason: forbidden);
      }
    });

    testWidgets('placeholders display generic non-production text only',
        (tester) async {
      await tester.pumpWidget(
        const Column(
          children: <Widget>[
            NonProductionCallV2ConnectingPlaceholder(),
            NonProductionCallV2ReadyPlaceholder(),
            NonProductionCallV2FailurePlaceholder(
              errorCode: CallV2ClientErrorCode.rejected,
            ),
          ],
        ),
      );

      expect(find.text('Call V2 connecting placeholder'), findsOneWidget);
      expect(find.text('Call V2 ready placeholder'), findsOneWidget);
      expect(find.text('Call V2 unavailable'), findsOneWidget);

      for (final forbidden in <String>[
        'call',
        'uid',
        'participant',
        'token',
        'channel',
        'microphone',
        'camera',
        'rejected',
      ]) {
        expect(
            find.textContaining(forbidden, findRichText: true), findsNothing);
      }
    });
  });
}

Future<void> _pumpRoute(WidgetTester tester, Route<dynamic> route) async {
  await tester.pumpWidget(
    MaterialApp(
      onGenerateRoute: (_) => route,
    ),
  );
  await tester.pumpAndSettle();
}

String _factorySource() {
  return <String>[
    'lib/call_v2/integration/call_v2_route_factory.dart',
    'lib/call_v2/integration/non_production_call_v2_route_factory.dart',
  ].map(_read).join('\n');
}

String _placeholderSource() {
  return Directory('lib/call_v2/integration/non_production')
      .listSync(recursive: true)
      .whereType<File>()
      .map((file) => file.readAsStringSync())
      .join('\n');
}

String _read(String path) => File(path).readAsStringSync();
