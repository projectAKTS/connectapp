import 'call_v2_diagnostic_event.dart';

abstract interface class CallV2Observer {
  Future<void> record(CallV2DiagnosticEvent event);
}

class CallV2NoopObserver implements CallV2Observer {
  const CallV2NoopObserver();

  @override
  Future<void> record(CallV2DiagnosticEvent event) async {}
}
