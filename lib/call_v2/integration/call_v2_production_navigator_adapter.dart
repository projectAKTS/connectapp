import 'package:flutter/widgets.dart';

import '../ui/call_v2_production_route_destination.dart';
import 'call_v2_production_route_sink_adapter.dart';

typedef CallV2NavigatorProvider = Object? Function();
typedef CallV2CurrentRouteNameProvider = String? Function();

enum CallV2ProductionNavigatorAdapterFailure {
  disposed,
  navigatorUnavailable,
  invalidRouteName,
  unsafeRouteArguments,
  noOwnedCallRoute,
}

final class CallV2ProductionNavigatorAdapterException implements Exception {
  const CallV2ProductionNavigatorAdapterException(this.reason);

  final CallV2ProductionNavigatorAdapterFailure reason;

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{'reason': reason.name};
  }

  @override
  String toString() {
    return 'CallV2ProductionNavigatorAdapterException(${toSafeDebugMap()})';
  }
}

final class CallV2ProductionNavigatorAdapter
    implements CallV2ProductionRouteSinkAdapter {
  CallV2ProductionNavigatorAdapter({
    required CallV2NavigatorProvider navigatorProvider,
    required CallV2CurrentRouteNameProvider currentRouteNameProvider,
  })  : _navigatorProvider = navigatorProvider,
        _currentRouteNameProvider = currentRouteNameProvider;

  final CallV2NavigatorProvider _navigatorProvider;
  final CallV2CurrentRouteNameProvider _currentRouteNameProvider;

  String? _ownedRouteName;
  bool _disposed = false;

  @override
  bool get isDisposed => _disposed;

  String? get ownedRouteName => _ownedRouteName;

  void dispose() {
    _disposed = true;
    _ownedRouteName = null;
  }

  @override
  Future<void> push(Route<dynamic> route) async {
    final routeName = _validatedRouteName(route);
    final navigator = _requireNavigator();
    navigator.push<dynamic>(route);
    _ownedRouteName = routeName;
  }

  @override
  Future<void> replace(Route<dynamic> route) async {
    final routeName = _validatedRouteName(route);
    final navigator = _requireNavigator();
    navigator.pushReplacement<dynamic, dynamic>(route);
    _ownedRouteName = routeName;
  }

  @override
  Future<void> popCallV2Route() async {
    final ownedRouteName = _ownedRouteName;
    if (ownedRouteName == null) return;
    final currentRouteName = _currentRouteNameProvider();
    if (currentRouteName != ownedRouteName ||
        !_isCanonicalRouteName(ownedRouteName)) {
      return;
    }
    final navigator = _requireNavigator();
    if (!navigator.canPop()) return;
    navigator.pop();
    _ownedRouteName = null;
  }

  dynamic _requireNavigator() {
    if (_disposed) {
      throw const CallV2ProductionNavigatorAdapterException(
        CallV2ProductionNavigatorAdapterFailure.disposed,
      );
    }
    final navigator = _navigatorProvider();
    if (navigator == null) {
      throw const CallV2ProductionNavigatorAdapterException(
        CallV2ProductionNavigatorAdapterFailure.navigatorUnavailable,
      );
    }
    return navigator;
  }

  String _validatedRouteName(Route<dynamic> route) {
    if (_disposed) {
      throw const CallV2ProductionNavigatorAdapterException(
        CallV2ProductionNavigatorAdapterFailure.disposed,
      );
    }
    final name = route.settings.name;
    if (name == null || !_isCanonicalRouteName(name)) {
      throw const CallV2ProductionNavigatorAdapterException(
        CallV2ProductionNavigatorAdapterFailure.invalidRouteName,
      );
    }
    if (!_hasSafeArguments(route.settings.arguments)) {
      throw const CallV2ProductionNavigatorAdapterException(
        CallV2ProductionNavigatorAdapterFailure.unsafeRouteArguments,
      );
    }
    return name;
  }

  bool _hasSafeArguments(Object? arguments) {
    return arguments == null;
  }

  bool _isCanonicalRouteName(String routeName) {
    return routeName == CallV2ProductionRouteNames.connecting ||
        routeName == CallV2ProductionRouteNames.activeAudio ||
        routeName == CallV2ProductionRouteNames.activeVideo ||
        routeName == CallV2ProductionRouteNames.controlledFailure;
  }
}
