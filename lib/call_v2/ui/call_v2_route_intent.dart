import '../call_v2_api.dart';

sealed class CallV2RouteIntent {
  const CallV2RouteIntent();
}

final class CallV2OpenConnectingRoute extends CallV2RouteIntent {
  const CallV2OpenConnectingRoute();

  @override
  String toString() => 'CallV2OpenConnectingRoute()';
}

final class CallV2OpenReadyCallRoute extends CallV2RouteIntent {
  const CallV2OpenReadyCallRoute();

  @override
  String toString() => 'CallV2OpenReadyCallRoute()';
}

final class CallV2CloseCallFlow extends CallV2RouteIntent {
  const CallV2CloseCallFlow();

  @override
  String toString() => 'CallV2CloseCallFlow()';
}

final class CallV2ShowControlledFailure extends CallV2RouteIntent {
  const CallV2ShowControlledFailure({required this.errorCode});

  final CallV2ClientErrorCode errorCode;

  @override
  String toString() {
    return 'CallV2ShowControlledFailure(errorCode: $errorCode)';
  }
}
