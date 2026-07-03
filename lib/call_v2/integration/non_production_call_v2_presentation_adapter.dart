import '../call_v2_api.dart';
import '../ui/call_v2_route_intent.dart';
import 'call_v2_presentation_adapter.dart';
import 'call_v2_route_factory.dart';
import 'call_v2_route_sink.dart';

final class NonProductionCallV2PresentationAdapter
    implements CallV2PresentationAdapter {
  NonProductionCallV2PresentationAdapter({
    required CallV2RouteFactory routeFactory,
    required CallV2RouteSink routeSink,
    bool ownsRouteSink = false,
  })  : _routeFactory = routeFactory,
        _routeSink = routeSink,
        _ownsRouteSink = ownsRouteSink;

  final CallV2RouteFactory _routeFactory;
  final CallV2RouteSink _routeSink;
  final bool _ownsRouteSink;

  Future<void> _tail = Future<void>.value();
  Future<void>? _disposeFuture;
  bool _disposed = false;
  bool _sinkCloseRequested = false;
  int _generation = 0;

  @override
  Future<void> handle(CallV2RouteIntent intent) {
    if (_disposed) {
      return Future<void>.error(
        const CallV2ClientError(CallV2ClientErrorCode.rejected),
      );
    }

    final generation = _generation;
    final operation = _tail.then((_) => _handleNow(intent, generation));
    _tail = operation.catchError((_) {});
    return operation;
  }

  Future<void> _handleNow(
    CallV2RouteIntent intent,
    int generation,
  ) async {
    _requireCurrent(generation);

    try {
      switch (intent) {
        case CallV2OpenConnectingRoute():
          final route = _routeFactory.create(
            const CallV2RouteDestination.connecting(),
          );
          _requireCurrent(generation);
          await _routeSink.open(route);
          _requireCurrent(generation);
        case CallV2OpenReadyCallRoute():
          final route = _routeFactory.create(
            const CallV2RouteDestination.ready(),
          );
          _requireCurrent(generation);
          await _routeSink.open(route);
          _requireCurrent(generation);
        case CallV2ShowControlledFailure(:final errorCode):
          final route = _routeFactory.create(
            CallV2RouteDestination.controlledFailure(errorCode: errorCode),
          );
          _requireCurrent(generation);
          await _routeSink.open(route);
          _requireCurrent(generation);
        case CallV2CloseCallFlow():
          await _closeSinkOnce();
          _requireCurrent(generation);
      }
    } on CallV2ClientError {
      rethrow;
    } catch (_) {
      throw const CallV2ClientError(CallV2ClientErrorCode.unavailable);
    }
  }

  @override
  Future<void> dispose() {
    final existing = _disposeFuture;
    if (existing != null) return existing;

    _disposed = true;
    _generation += 1;

    if (!_ownsRouteSink) {
      _disposeFuture = Future<void>.value();
      return _disposeFuture!;
    }

    final future = _closeOwnedSink();
    _disposeFuture = future;
    return future;
  }

  Future<void> _closeOwnedSink() async {
    try {
      await _closeSinkOnce();
    } on CallV2ClientError {
      rethrow;
    } catch (_) {
      throw const CallV2ClientError(CallV2ClientErrorCode.unavailable);
    }
  }

  Future<void> _closeSinkOnce() async {
    if (_sinkCloseRequested) return;
    _sinkCloseRequested = true;
    try {
      await _routeSink.close();
    } on CallV2ClientError {
      rethrow;
    } catch (_) {
      throw const CallV2ClientError(CallV2ClientErrorCode.unavailable);
    }
  }

  void _requireCurrent(int generation) {
    if (_disposed || generation != _generation) {
      throw const CallV2ClientError(CallV2ClientErrorCode.rejected);
    }
  }
}
