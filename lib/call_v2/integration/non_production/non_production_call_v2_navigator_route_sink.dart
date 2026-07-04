import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../call_v2_api.dart';
import '../call_v2_route_sink.dart';

typedef NonProductionCallV2NavigatorReader = NavigatorState? Function();

final class NonProductionCallV2NavigatorRouteSink implements CallV2RouteSink {
  NonProductionCallV2NavigatorRouteSink({
    required NonProductionCallV2NavigatorReader navigatorReader,
  }) : _navigatorReader = navigatorReader;

  NonProductionCallV2NavigatorRouteSink.fromNavigatorKey({
    required GlobalKey<NavigatorState> navigatorKey,
  }) : _navigatorReader = (() => navigatorKey.currentState);

  final NonProductionCallV2NavigatorReader _navigatorReader;
  final List<Route<dynamic>> _ownedRoutes = <Route<dynamic>>[];

  Future<void> _tail = Future<void>.value();
  Future<void>? _disposeFuture;
  var _disposed = false;
  var _generation = 0;

  bool get isDisposed => _disposed;
  int get ownedRouteCount => _ownedRoutes.length;

  @override
  Future<void> open(Route<dynamic> route) {
    if (_disposed) {
      return Future<void>.error(
        const CallV2ClientError(CallV2ClientErrorCode.rejected),
      );
    }

    final generation = _generation;
    final operation = _tail.then((_) => _openNow(route, generation));
    _tail = operation.catchError((_) {});
    return operation;
  }

  @override
  Future<void> close() {
    if (_disposed) return Future<void>.value();

    final generation = _generation;
    final operation = _tail.then((_) => _closeNow(generation));
    _tail = operation.catchError((_) {});
    return operation;
  }

  Future<void> dispose() {
    final existing = _disposeFuture;
    if (existing != null) return existing;
    if (_disposed) return Future<void>.value();

    final future = _dispose().whenComplete(() {
      _disposeFuture = null;
    });
    _disposeFuture = future;
    return future;
  }

  Future<void> _openNow(Route<dynamic> route, int generation) async {
    _requireCurrent(generation);
    final navigator = _requireNavigator();

    try {
      unawaited(navigator.push<dynamic>(route));
      _requireCurrent(generation);
      _ownedRoutes.add(route);
    } on CallV2ClientError {
      rethrow;
    } catch (_) {
      throw const CallV2ClientError(CallV2ClientErrorCode.unavailable);
    }
  }

  Future<void> _closeNow(int generation) async {
    _requireCurrent(generation);
    final navigator = _navigatorReader();
    if (navigator == null) {
      _ownedRoutes.clear();
      return;
    }

    try {
      _removeOwnedRoutes(navigator);
    } on CallV2ClientError {
      rethrow;
    } catch (_) {
      throw const CallV2ClientError(CallV2ClientErrorCode.unavailable);
    }
  }

  Future<void> _dispose() async {
    _disposed = true;
    _generation += 1;

    CallV2ClientErrorCode? errorCode;
    try {
      await _tail;
    } on CallV2ClientError catch (error) {
      errorCode ??= error.code;
    } catch (_) {
      errorCode ??= CallV2ClientErrorCode.unavailable;
    }

    final navigator = _navigatorReader();
    if (navigator != null) {
      try {
        _removeOwnedRoutes(navigator);
      } on CallV2ClientError catch (error) {
        errorCode ??= error.code;
      } catch (_) {
        errorCode ??= CallV2ClientErrorCode.unavailable;
      }
    } else {
      _ownedRoutes.clear();
    }

    if (errorCode != null) {
      throw CallV2ClientError(errorCode);
    }
  }

  NavigatorState _requireNavigator() {
    final navigator = _navigatorReader();
    if (navigator == null) {
      throw const CallV2ClientError(CallV2ClientErrorCode.unavailable);
    }
    return navigator;
  }

  void _removeOwnedRoutes(NavigatorState navigator) {
    final routes = List<Route<dynamic>>.of(_ownedRoutes.reversed);
    _ownedRoutes.clear();
    for (final route in routes) {
      navigator.removeRoute(route);
    }
  }

  void _requireCurrent(int generation) {
    if (_disposed || generation != _generation) {
      throw const CallV2ClientError(CallV2ClientErrorCode.rejected);
    }
  }
}
