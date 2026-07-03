import 'dart:async';

import '../call_v2_api.dart';
import '../ui/call_v2_route_intent.dart';
import '../ui/call_v2_ui_integration.dart';
import 'call_v2_presentation_adapter.dart';
import 'call_v2_test_harness.dart';

enum NonProductionCallV2TestHarnessStatus {
  idle,
  running,
  stopped,
  failed,
  disposed,
}

final class NonProductionCallV2TestHarnessState {
  const NonProductionCallV2TestHarnessState({
    required this.status,
    this.errorCode,
  });

  static const idle = NonProductionCallV2TestHarnessState(
    status: NonProductionCallV2TestHarnessStatus.idle,
  );

  final NonProductionCallV2TestHarnessStatus status;
  final CallV2ClientErrorCode? errorCode;

  @override
  String toString() {
    return 'NonProductionCallV2TestHarnessState('
        'status: $status, '
        'errorCode: $errorCode'
        ')';
  }
}

final class NonProductionCallV2TestHarness implements CallV2TestHarness {
  NonProductionCallV2TestHarness({
    required CallV2UiCoordinator coordinator,
    required CallV2PresentationAdapter presentationAdapter,
    bool ownsCoordinator = false,
    bool ownsPresentationAdapter = false,
  })  : _coordinator = coordinator,
        _presentationAdapter = presentationAdapter,
        _ownsCoordinator = ownsCoordinator,
        _ownsPresentationAdapter = ownsPresentationAdapter;

  final CallV2UiCoordinator _coordinator;
  final CallV2PresentationAdapter _presentationAdapter;
  final bool _ownsCoordinator;
  final bool _ownsPresentationAdapter;

  StreamSubscription<CallV2RouteIntent>? _subscription;
  Future<void> _tail = Future<void>.value();
  Future<void>? _startFuture;
  Future<void>? _stopFuture;
  Future<void>? _disposeFuture;
  var _state = NonProductionCallV2TestHarnessState.idle;
  var _generation = 0;

  NonProductionCallV2TestHarnessState get state => _state;

  @override
  Future<void> start() {
    final existing = _startFuture;
    if (existing != null) return existing;
    if (_state.status == NonProductionCallV2TestHarnessStatus.disposed) {
      return Future<void>.error(
        const CallV2ClientError(CallV2ClientErrorCode.rejected),
      );
    }
    if (_state.status == NonProductionCallV2TestHarnessStatus.running) {
      return Future<void>.value();
    }
    if (_state.status == NonProductionCallV2TestHarnessStatus.failed) {
      return Future<void>.error(
        CallV2ClientError(
          _state.errorCode ?? CallV2ClientErrorCode.unavailable,
        ),
      );
    }

    final future = _start().whenComplete(() {
      _startFuture = null;
    });
    _startFuture = future;
    return future;
  }

  Future<void> _start() async {
    try {
      final generation = ++_generation;
      _subscription = _coordinator.routeIntents.listen(
        (intent) => _enqueue(intent, generation),
        onError: (Object _) => _fail(
          generation,
          CallV2ClientErrorCode.unavailable,
        ),
        cancelOnError: false,
      );
      _state = const NonProductionCallV2TestHarnessState(
        status: NonProductionCallV2TestHarnessStatus.running,
      );
    } catch (_) {
      _state = const NonProductionCallV2TestHarnessState(
        status: NonProductionCallV2TestHarnessStatus.failed,
        errorCode: CallV2ClientErrorCode.unavailable,
      );
      throw const CallV2ClientError(CallV2ClientErrorCode.unavailable);
    }
  }

  void _enqueue(CallV2RouteIntent intent, int generation) {
    if (!_isCurrentRunning(generation)) return;

    final operation = _tail.then((_) => _forward(intent, generation));
    _tail = operation.catchError((_) {});
  }

  Future<void> _forward(
    CallV2RouteIntent intent,
    int generation,
  ) async {
    if (!_isCurrentRunning(generation)) return;

    try {
      await _presentationAdapter.handle(intent);
      if (!_isCurrentRunning(generation)) return;
    } on CallV2ClientError catch (error) {
      _fail(generation, error.code);
      rethrow;
    } catch (_) {
      _fail(generation, CallV2ClientErrorCode.unavailable);
      throw const CallV2ClientError(CallV2ClientErrorCode.unavailable);
    }
  }

  void _fail(int generation, CallV2ClientErrorCode errorCode) {
    if (!_isCurrentRunning(generation)) return;
    _state = NonProductionCallV2TestHarnessState(
      status: NonProductionCallV2TestHarnessStatus.failed,
      errorCode: errorCode,
    );
    unawaited(_subscription?.cancel());
    _subscription = null;
  }

  @override
  Future<void> stop() {
    final existing = _stopFuture;
    if (existing != null) return existing;
    if (_state.status == NonProductionCallV2TestHarnessStatus.disposed) {
      return Future<void>.value();
    }
    if (_state.status == NonProductionCallV2TestHarnessStatus.stopped ||
        _state.status == NonProductionCallV2TestHarnessStatus.idle) {
      return Future<void>.value();
    }

    final future = _stop(markStopped: true).whenComplete(() {
      _stopFuture = null;
    });
    _stopFuture = future;
    return future;
  }

  Future<void> _stop({required bool markStopped}) async {
    final generation = ++_generation;
    CallV2ClientErrorCode? errorCode;

    try {
      await _subscription?.cancel();
    } on CallV2ClientError catch (error) {
      errorCode ??= error.code;
    } catch (_) {
      errorCode ??= CallV2ClientErrorCode.unavailable;
    } finally {
      _subscription = null;
    }

    try {
      await _tail;
    } on CallV2ClientError catch (error) {
      errorCode ??= error.code;
    } catch (_) {
      errorCode ??= CallV2ClientErrorCode.unavailable;
    } finally {
      if (generation == _generation && markStopped) {
        _state = NonProductionCallV2TestHarnessState(
          status: NonProductionCallV2TestHarnessStatus.stopped,
          errorCode: errorCode,
        );
      }
    }

    if (errorCode != null) {
      throw CallV2ClientError(errorCode);
    }
  }

  @override
  Future<void> dispose() {
    final existing = _disposeFuture;
    if (existing != null) return existing;
    if (_state.status == NonProductionCallV2TestHarnessStatus.disposed) {
      return Future<void>.value();
    }

    final future = _dispose().whenComplete(() {
      _disposeFuture = null;
    });
    _disposeFuture = future;
    return future;
  }

  Future<void> _dispose() async {
    _state = const NonProductionCallV2TestHarnessState(
      status: NonProductionCallV2TestHarnessStatus.disposed,
    );

    CallV2ClientErrorCode? errorCode;

    try {
      await _stop(markStopped: false);
    } on CallV2ClientError catch (error) {
      errorCode ??= error.code;
    } catch (_) {
      errorCode ??= CallV2ClientErrorCode.unavailable;
    }

    if (_ownsPresentationAdapter) {
      try {
        await _presentationAdapter.dispose();
      } on CallV2ClientError catch (error) {
        errorCode ??= error.code;
      } catch (_) {
        errorCode ??= CallV2ClientErrorCode.unavailable;
      }
    }

    if (_ownsCoordinator) {
      try {
        await _coordinator.dispose();
      } on CallV2ClientError catch (error) {
        errorCode ??= error.code;
      } catch (_) {
        errorCode ??= CallV2ClientErrorCode.unavailable;
      }
    }

    _state = NonProductionCallV2TestHarnessState(
      status: NonProductionCallV2TestHarnessStatus.disposed,
      errorCode: errorCode,
    );
    if (errorCode != null) {
      throw CallV2ClientError(errorCode);
    }
  }

  bool _isCurrentRunning(int generation) {
    return generation == _generation &&
        _state.status == NonProductionCallV2TestHarnessStatus.running;
  }
}
