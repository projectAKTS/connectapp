import 'package:connect_app/call_v2/integration/call_v2_production_navigator_adapter.dart';
import 'package:connect_app/call_v2/integration/call_v2_production_navigator_port.dart';
import 'package:connect_app/call_v2/integration/call_v2_production_route_sink_adapter.dart';
import 'package:connect_app/call_v2/ui/call_v2_production_route_destination.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('adapter implements route sink adapter', (tester) async {
    final harness = await _pumpHarness(tester);

    expect(harness.adapter, isA<CallV2ProductionRouteSinkAdapter>());
  });

  test('fake navigator port can be injected', () async {
    final port = _FakeNavigatorPort();
    var currentRouteName = CallV2ProductionRouteNames.connecting;
    final adapter = CallV2ProductionNavigatorAdapter(
      navigatorProvider: () => port,
      currentRouteNameProvider: () => currentRouteName,
    );

    await adapter.push(_route(CallV2ProductionRouteNames.connecting));
    currentRouteName = CallV2ProductionRouteNames.activeAudio;
    await adapter.replace(_route(CallV2ProductionRouteNames.activeAudio));
    await adapter.popCallV2Route();

    expect(port.pushed, <String>[CallV2ProductionRouteNames.connecting]);
    expect(port.replaced, <String>[CallV2ProductionRouteNames.activeAudio]);
    expect(port.popCount, 1);
  });

  test('navigator provider contract is typed to the minimal port', () {
    CallV2ProductionNavigatorPort? typedProvider() => _FakeNavigatorPort();
    final adapter = CallV2ProductionNavigatorAdapter(
      navigatorProvider: typedProvider,
      currentRouteNameProvider: () => null,
    );

    expect(adapter, isA<CallV2ProductionRouteSinkAdapter>());
  });

  testWidgets('push accepts every exact canonical Call V2 route',
      (tester) async {
    for (final routeName in <String>[
      CallV2ProductionRouteNames.connecting,
      CallV2ProductionRouteNames.activeAudio,
      CallV2ProductionRouteNames.activeVideo,
      CallV2ProductionRouteNames.controlledFailure,
    ]) {
      final harness = await _pumpHarness(tester);

      await harness.adapter.push(_route(routeName));
      await tester.pumpAndSettle();

      expect(harness.observer.currentRouteName, routeName);
      expect(harness.adapter.ownedRouteName, routeName);
      expect(harness.observer.pushed, <String>['/home', routeName]);
    }
  });

  testWidgets('replace accepts exact canonical Call V2 route', (tester) async {
    final harness = await _pumpHarness(tester);
    await harness.adapter.push(_route(CallV2ProductionRouteNames.connecting));
    await tester.pumpAndSettle();

    await harness.adapter
        .replace(_route(CallV2ProductionRouteNames.activeAudio));
    await tester.pumpAndSettle();

    expect(harness.observer.currentRouteName,
        CallV2ProductionRouteNames.activeAudio);
    expect(
        harness.adapter.ownedRouteName, CallV2ProductionRouteNames.activeAudio);
    expect(harness.observer.replaced, <String>[
      CallV2ProductionRouteNames.connecting,
      CallV2ProductionRouteNames.activeAudio,
    ]);
  });

  testWidgets(
      'push rejects query fragment whitespace suffix arbitrary and ready',
      (tester) async {
    final rejected = <String>[
      '${CallV2ProductionRouteNames.activeAudio}?uid=abc',
      '${CallV2ProductionRouteNames.activeAudio}#token',
      '${CallV2ProductionRouteNames.activeAudio} ',
      '${CallV2ProductionRouteNames.activeAudio}/extra',
      '/not-call-v2/audio',
      '/call-v2/ready',
    ];

    for (final routeName in rejected) {
      final harness = await _pumpHarness(tester);

      expect(
        harness.adapter.push(_route(routeName)),
        throwsA(_adapterFailure(
          CallV2ProductionNavigatorAdapterFailure.invalidRouteName,
        )),
      );
      await tester.pumpAndSettle();
      expect(harness.observer.currentRouteName, '/home');
      expect(harness.adapter.ownedRouteName, isNull);
    }
  });

  testWidgets('replace rejects unsafe routes', (tester) async {
    final harness = await _pumpHarness(tester);

    expect(
      harness.adapter.replace(_route('/call-v2/ready')),
      throwsA(_adapterFailure(
        CallV2ProductionNavigatorAdapterFailure.invalidRouteName,
      )),
    );
    await tester.pumpAndSettle();

    expect(harness.observer.currentRouteName, '/home');
    expect(harness.adapter.ownedRouteName, isNull);
  });

  testWidgets('route settings arguments must be null', (tester) async {
    final harness = await _pumpHarness(tester);

    await harness.adapter.push(_route(CallV2ProductionRouteNames.activeAudio));
    await tester.pumpAndSettle();
    expect(
        harness.adapter.ownedRouteName, CallV2ProductionRouteNames.activeAudio);

    for (final arguments in <Object?>[
      <String, Object?>{'callId': 'secret'},
      <String>['token'],
      'uid-secret',
      1,
      true,
    ]) {
      final fresh = await _pumpHarness(tester);
      expect(
        fresh.adapter.push(
          _route(
            CallV2ProductionRouteNames.activeAudio,
            arguments: arguments,
          ),
        ),
        throwsA(_adapterFailure(
          CallV2ProductionNavigatorAdapterFailure.unsafeRouteArguments,
        )),
      );
      await tester.pumpAndSettle();
      expect(fresh.adapter.ownedRouteName, isNull);
    }
  });

  testWidgets('navigator unavailable and disposed are controlled failures',
      (tester) async {
    final unavailable = CallV2ProductionNavigatorAdapter(
      navigatorProvider: () => null,
      currentRouteNameProvider: () => null,
    );
    expect(
      unavailable.push(_route(CallV2ProductionRouteNames.activeAudio)),
      throwsA(_adapterFailure(
        CallV2ProductionNavigatorAdapterFailure.navigatorUnavailable,
      )),
    );

    final harness = await _pumpHarness(tester);
    harness.adapter.dispose();
    harness.adapter.dispose();

    expect(harness.adapter.isDisposed, isTrue);
    expect(harness.adapter.ownedRouteName, isNull);
    expect(
      harness.adapter.push(_route(CallV2ProductionRouteNames.activeAudio)),
      throwsA(_adapterFailure(
        CallV2ProductionNavigatorAdapterFailure.disposed,
      )),
    );
  });

  testWidgets('popCallV2Route pops only adapter-owned Call V2 route',
      (tester) async {
    final harness = await _pumpHarness(tester);
    await harness.adapter.push(_route(CallV2ProductionRouteNames.activeAudio));
    await tester.pumpAndSettle();

    await harness.adapter.popCallV2Route();
    await tester.pumpAndSettle();

    expect(harness.observer.currentRouteName, '/home');
    expect(harness.adapter.ownedRouteName, isNull);
    expect(harness.observer.popped, <String>[
      CallV2ProductionRouteNames.activeAudio,
    ]);

    await harness.adapter.popCallV2Route();
    await tester.pumpAndSettle();
    expect(harness.observer.popped, <String>[
      CallV2ProductionRouteNames.activeAudio,
    ]);
  });

  testWidgets('popCallV2Route does not pop non-Call V2 current routes',
      (tester) async {
    for (final routeName in <String>[
      '/v1/call',
      '/home',
      '/chat',
      '/profile/abc',
      '/post/abc',
      '/call-v2/ready',
    ]) {
      final harness = await _pumpHarness(tester);
      await harness.adapter
          .push(_route(CallV2ProductionRouteNames.activeAudio));
      await tester.pumpAndSettle();
      harness.navigator.push<dynamic>(_route(routeName));
      await tester.pumpAndSettle();

      await harness.adapter.popCallV2Route();
      await tester.pumpAndSettle();

      expect(harness.observer.currentRouteName, routeName);
      expect(harness.observer.popped, isEmpty);
      expect(harness.adapter.ownedRouteName,
          CallV2ProductionRouteNames.activeAudio);
    }
  });

  test('adapter exception debug output is safe', () {
    const exception = CallV2ProductionNavigatorAdapterException(
      CallV2ProductionNavigatorAdapterFailure.invalidRouteName,
    );
    final debug = exception.toString();

    expect(debug, contains('invalidRouteName'));
    for (final forbidden in <String>[
      '/call-v2',
      '/home',
      'uid',
      'callId',
      'participant',
      'token',
      'channel',
      'credential',
      'StackTrace',
    ]) {
      expect(debug, isNot(contains(forbidden)), reason: forbidden);
    }
  });
}

Matcher _adapterFailure(CallV2ProductionNavigatorAdapterFailure failure) {
  return isA<CallV2ProductionNavigatorAdapterException>()
      .having((error) => error.reason, 'reason', failure);
}

Route<dynamic> _route(String name, {Object? arguments}) {
  return PageRouteBuilder<dynamic>(
    settings: RouteSettings(name: name, arguments: arguments),
    pageBuilder: (_, __, ___) => const SizedBox.shrink(),
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
  );
}

Future<_Harness> _pumpHarness(WidgetTester tester) async {
  final observer = _TrackingNavigatorObserver();
  await tester.pumpWidget(
    MaterialApp(
      navigatorObservers: <NavigatorObserver>[observer],
      initialRoute: '/home',
      routes: <String, WidgetBuilder>{
        '/home': (_) => const SizedBox.shrink(),
      },
    ),
  );
  await tester.pumpAndSettle();
  final navigator = tester.state<NavigatorState>(find.byType(Navigator));
  final navigatorPort = _WidgetNavigatorPort(navigator);
  observer.markInitialRoute('/home');
  final adapter = CallV2ProductionNavigatorAdapter(
    navigatorProvider: () => navigatorPort,
    currentRouteNameProvider: () => observer.currentRouteName,
  );
  return _Harness(
    adapter: adapter,
    navigator: navigator,
    observer: observer,
  );
}

final class _Harness {
  const _Harness({
    required this.adapter,
    required this.navigator,
    required this.observer,
  });

  final CallV2ProductionNavigatorAdapter adapter;
  final NavigatorState navigator;
  final _TrackingNavigatorObserver observer;
}

final class _WidgetNavigatorPort implements CallV2ProductionNavigatorPort {
  const _WidgetNavigatorPort(this._navigator);

  final NavigatorState _navigator;

  @override
  Future<void> push(Route<dynamic> route) async {
    _navigator.push<dynamic>(route);
  }

  @override
  Future<void> pushReplacement(Route<dynamic> route) async {
    _navigator.pushReplacement<dynamic, dynamic>(route);
  }

  @override
  bool canPop() => _navigator.canPop();

  @override
  void pop() {
    _navigator.pop();
  }
}

final class _FakeNavigatorPort implements CallV2ProductionNavigatorPort {
  final List<String> pushed = <String>[];
  final List<String> replaced = <String>[];
  var popCount = 0;

  @override
  Future<void> push(Route<dynamic> route) async {
    final name = route.settings.name;
    if (name != null) pushed.add(name);
  }

  @override
  Future<void> pushReplacement(Route<dynamic> route) async {
    final name = route.settings.name;
    if (name != null) replaced.add(name);
  }

  @override
  bool canPop() => true;

  @override
  void pop() {
    popCount += 1;
  }
}

final class _TrackingNavigatorObserver extends NavigatorObserver {
  final List<String> pushed = <String>[];
  final List<String> popped = <String>[];
  final List<String> replaced = <String>[];
  String? currentRouteName;

  void markInitialRoute(String routeName) {
    if (currentRouteName == null) {
      currentRouteName = routeName;
      pushed.add(routeName);
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final name = route.settings.name;
    if (name != null) {
      pushed.add(name);
      currentRouteName = name;
    }
    super.didPush(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final oldName = oldRoute?.settings.name;
    final newName = newRoute?.settings.name;
    if (oldName != null && newName != null) {
      replaced.add(oldName);
      replaced.add(newName);
      currentRouteName = newName;
    }
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final name = route.settings.name;
    if (name != null) {
      popped.add(name);
    }
    currentRouteName = previousRoute?.settings.name;
    super.didPop(route, previousRoute);
  }
}
