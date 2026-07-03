import 'dart:async';

import 'package:connect_app/call_v2/call_v2_api.dart';
import 'package:connect_app/call_v2/integration/call_v2_route_factory.dart';
import 'package:connect_app/call_v2/integration/call_v2_route_sink.dart';
import 'package:connect_app/call_v2/integration/non_production_call_v2_presentation_adapter.dart';
import 'package:connect_app/call_v2/ui/call_v2_route_intent.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('construction and dependencies', () {
    test('constructor has no side effects and uses injected dependencies', () {
      final factory = _RecordingRouteFactory();
      final sink = _RecordingRouteSink();

      NonProductionCallV2PresentationAdapter(
        routeFactory: factory,
        routeSink: sink,
      );

      expect(factory.destinations, isEmpty);
      expect(sink.events, isEmpty);
    });
  });

  group('intent mapping', () {
    test('connecting intent maps to connecting destination and one route',
        () async {
      final factory = _RecordingRouteFactory();
      final sink = _RecordingRouteSink();
      final adapter = _adapter(factory, sink);

      await adapter.handle(const CallV2OpenConnectingRoute());

      expect(factory.destinations, hasLength(1));
      expect(
          factory.destinations.single, isA<CallV2ConnectingRouteDestination>());
      expect(sink.openedNames, <String>[CallV2RouteFactoryNames.connecting]);
      expect(sink.closeCount, 0);
    });

    test('ready intent maps to ready destination and one route', () async {
      final factory = _RecordingRouteFactory();
      final sink = _RecordingRouteSink();
      final adapter = _adapter(factory, sink);

      await adapter.handle(const CallV2OpenReadyCallRoute());

      expect(factory.destinations, hasLength(1));
      expect(factory.destinations.single, isA<CallV2ReadyRouteDestination>());
      expect(sink.openedNames, <String>[CallV2RouteFactoryNames.ready]);
      expect(sink.closeCount, 0);
    });

    test('failure intent maps only controlled error code', () async {
      final factory = _RecordingRouteFactory();
      final sink = _RecordingRouteSink();
      final adapter = _adapter(factory, sink);

      await adapter.handle(
        const CallV2ShowControlledFailure(
          errorCode: CallV2ClientErrorCode.unauthorized,
        ),
      );

      final destination = factory.destinations.single;
      expect(destination, isA<CallV2ControlledFailureRouteDestination>());
      expect(
        (destination as CallV2ControlledFailureRouteDestination).errorCode,
        CallV2ClientErrorCode.unauthorized,
      );
      expect(
        sink.openedNames,
        <String>[CallV2RouteFactoryNames.controlledFailure],
      );
    });

    test('close intent calls sink close and creates no route', () async {
      final factory = _RecordingRouteFactory();
      final sink = _RecordingRouteSink();
      final adapter = _adapter(factory, sink);

      await adapter.handle(const CallV2CloseCallFlow());

      expect(factory.destinations, isEmpty);
      expect(sink.openedNames, isEmpty);
      expect(sink.closeCount, 1);
    });

    test(
        'route settings remain identifier-free and no request data is accessed',
        () async {
      final factory = _RecordingRouteFactory();
      final sink = _RecordingRouteSink();
      final adapter = _adapter(factory, sink);

      await adapter.handle(const CallV2OpenConnectingRoute());
      await adapter.handle(const CallV2OpenReadyCallRoute());
      await adapter.handle(
        const CallV2ShowControlledFailure(
          errorCode: CallV2ClientErrorCode.unavailable,
        ),
      );

      for (final name in sink.openedNames) {
        expect(name, isNot(contains('uid')));
        expect(name, isNot(contains('callId')));
        expect(name, isNot(contains('token')));
        expect(name, isNot(contains(':')));
      }
    });
  });

  group('ordering and concurrency', () {
    test('sequential intents preserve order', () async {
      final factory = _RecordingRouteFactory();
      final sink = _RecordingRouteSink();
      final adapter = _adapter(factory, sink);

      await adapter.handle(const CallV2OpenConnectingRoute());
      await adapter.handle(const CallV2OpenReadyCallRoute());
      await adapter.handle(const CallV2CloseCallFlow());

      expect(sink.events, <String>[
        'open:${CallV2RouteFactoryNames.connecting}',
        'open:${CallV2RouteFactoryNames.ready}',
        'close',
      ]);
    });

    test('concurrent intents are delivered in call order', () async {
      final factory = _RecordingRouteFactory();
      final firstOpen = Completer<void>();
      final sink = _RecordingRouteSink(openCompleters: <Completer<void>>[
        firstOpen,
      ]);
      final adapter = _adapter(factory, sink);

      final first = adapter.handle(const CallV2OpenConnectingRoute());
      final second = adapter.handle(const CallV2OpenReadyCallRoute());

      await Future<void>.delayed(Duration.zero);
      expect(factory.destinations, hasLength(1));
      expect(sink.openedNames, <String>[CallV2RouteFactoryNames.connecting]);

      firstOpen.complete();
      await first;
      await second;

      expect(sink.openedNames, <String>[
        CallV2RouteFactoryNames.connecting,
        CallV2RouteFactoryNames.ready,
      ]);
    });

    test('explicit repeated intents remain deterministic', () async {
      final factory = _RecordingRouteFactory();
      final sink = _RecordingRouteSink();
      final adapter = _adapter(factory, sink);

      await adapter.handle(const CallV2OpenConnectingRoute());
      await adapter.handle(const CallV2OpenConnectingRoute());

      expect(factory.destinations, hasLength(2));
      expect(sink.openedNames, <String>[
        CallV2RouteFactoryNames.connecting,
        CallV2RouteFactoryNames.connecting,
      ]);
    });

    test('no retry or recursive failure route after factory failure', () async {
      final factory = _RecordingRouteFactory(
        factoryError: StateError('raw factory provider failure'),
      );
      final sink = _RecordingRouteSink();
      final adapter = _adapter(factory, sink);

      await expectLater(
        adapter.handle(const CallV2OpenConnectingRoute()),
        throwsA(_clientError(CallV2ClientErrorCode.unavailable)),
      );

      expect(factory.destinations, hasLength(1));
      expect(sink.openedNames, isEmpty);
      expect(sink.closeCount, 0);
    });

    test('sink failure does not create another route', () async {
      final factory = _RecordingRouteFactory();
      final sink = _RecordingRouteSink(
        openError: StateError('raw sink provider failure'),
      );
      final adapter = _adapter(factory, sink);

      await expectLater(
        adapter.handle(const CallV2OpenReadyCallRoute()),
        throwsA(_clientError(CallV2ClientErrorCode.unavailable)),
      );

      expect(factory.destinations, hasLength(1));
      expect(sink.openedNames, <String>[CallV2RouteFactoryNames.ready]);
      expect(sink.closeCount, 0);
    });

    test('close sink failure is controlled and does not retry', () async {
      final factory = _RecordingRouteFactory();
      final sink = _RecordingRouteSink(
        closeError: StateError('raw close provider failure'),
      );
      final adapter = _adapter(factory, sink);

      await expectLater(
        adapter.handle(const CallV2CloseCallFlow()),
        throwsA(_clientError(CallV2ClientErrorCode.unavailable)),
      );

      expect(factory.destinations, isEmpty);
      expect(sink.closeCount, 1);
    });
  });

  group('error safety', () {
    test('controlled client errors remain controlled', () async {
      final factory = _RecordingRouteFactory(
        factoryError: const CallV2ClientError(
          CallV2ClientErrorCode.invalidRequest,
        ),
      );
      final adapter = _adapter(factory, _RecordingRouteSink());

      await expectLater(
        adapter.handle(const CallV2OpenConnectingRoute()),
        throwsA(_clientError(CallV2ClientErrorCode.invalidRequest)),
      );
    });

    test('raw messages and stack traces are not exposed', () async {
      final adapter = _adapter(
        _RecordingRouteFactory(factoryError: StateError('secret raw detail')),
        _RecordingRouteSink(),
      );

      try {
        await adapter.handle(const CallV2OpenConnectingRoute());
        fail('expected failure');
      } on CallV2ClientError catch (error) {
        expect(error.code, CallV2ClientErrorCode.unavailable);
        expect(error.toString(), isNot(contains('secret raw detail')));
        expect(error.toString(), isNot(contains('StackTrace')));
      }
    });
  });

  group('dispose and races', () {
    test('dispose is idempotent and rejects later handle calls', () async {
      final sink = _RecordingRouteSink();
      final adapter = NonProductionCallV2PresentationAdapter(
        routeFactory: _RecordingRouteFactory(),
        routeSink: sink,
        ownsRouteSink: true,
      );

      await adapter.dispose();
      await adapter.dispose();

      expect(sink.closeCount, 1);
      await expectLater(
        adapter.handle(const CallV2OpenConnectingRoute()),
        throwsA(_clientError(CallV2ClientErrorCode.rejected)),
      );
    });

    test('queued factory work after dispose does not open route', () async {
      final firstOpen = Completer<void>();
      final factory = _RecordingRouteFactory();
      final sink = _RecordingRouteSink(openCompleters: <Completer<void>>[
        firstOpen,
      ]);
      final adapter = _adapter(factory, sink);

      final first = adapter.handle(const CallV2OpenConnectingRoute());
      final second = adapter.handle(const CallV2OpenReadyCallRoute());
      await Future<void>.delayed(Duration.zero);

      await adapter.dispose();
      firstOpen.complete();

      await expectLater(
        first,
        throwsA(_clientError(CallV2ClientErrorCode.rejected)),
      );
      await expectLater(
        second,
        throwsA(_clientError(CallV2ClientErrorCode.rejected)),
      );

      expect(factory.destinations, hasLength(1));
      expect(sink.openedNames, <String>[CallV2RouteFactoryNames.connecting]);
    });

    test('sink close ownership is explicit', () async {
      final unownedSink = _RecordingRouteSink();
      final unowned = NonProductionCallV2PresentationAdapter(
        routeFactory: _RecordingRouteFactory(),
        routeSink: unownedSink,
      );
      await unowned.dispose();
      expect(unownedSink.closeCount, 0);

      final ownedSink = _RecordingRouteSink();
      final owned = NonProductionCallV2PresentationAdapter(
        routeFactory: _RecordingRouteFactory(),
        routeSink: ownedSink,
        ownsRouteSink: true,
      );
      await owned.dispose();
      await owned.dispose();
      expect(ownedSink.closeCount, 1);
    });
  });
}

NonProductionCallV2PresentationAdapter _adapter(
  CallV2RouteFactory factory,
  CallV2RouteSink sink,
) {
  return NonProductionCallV2PresentationAdapter(
    routeFactory: factory,
    routeSink: sink,
  );
}

Matcher _clientError(CallV2ClientErrorCode code) {
  return isA<CallV2ClientError>().having((error) => error.code, 'code', code);
}

final class _RecordingRouteFactory implements CallV2RouteFactory {
  _RecordingRouteFactory({this.factoryError});

  final Object? factoryError;
  final List<CallV2RouteDestination> destinations = <CallV2RouteDestination>[];

  @override
  Route<dynamic> create(CallV2RouteDestination destination) {
    destinations.add(destination);
    final error = factoryError;
    if (error != null) throw error;
    return MaterialPageRoute<dynamic>(
      settings: RouteSettings(name: _nameFor(destination)),
      builder: (_) => const SizedBox.shrink(),
    );
  }

  String _nameFor(CallV2RouteDestination destination) {
    return switch (destination) {
      CallV2ConnectingRouteDestination() => CallV2RouteFactoryNames.connecting,
      CallV2ReadyRouteDestination() => CallV2RouteFactoryNames.ready,
      CallV2ControlledFailureRouteDestination() =>
        CallV2RouteFactoryNames.controlledFailure,
    };
  }
}

final class _RecordingRouteSink implements CallV2RouteSink {
  _RecordingRouteSink({
    List<Completer<void>> openCompleters = const <Completer<void>>[],
    this.openError,
    this.closeError,
  }) : _openCompleters = List<Completer<void>>.of(openCompleters);

  final List<Completer<void>> _openCompleters;
  final Object? openError;
  final Object? closeError;
  final List<String> events = <String>[];
  final List<String> openedNames = <String>[];
  int closeCount = 0;

  @override
  Future<void> open(Route<dynamic> route) async {
    final name = route.settings.name ?? '<unnamed>';
    events.add('open:$name');
    openedNames.add(name);
    if (_openCompleters.isNotEmpty) {
      await _openCompleters.removeAt(0).future;
    }
    final error = openError;
    if (error != null) throw error;
  }

  @override
  Future<void> close() async {
    events.add('close');
    closeCount += 1;
    final error = closeError;
    if (error != null) throw error;
  }
}
