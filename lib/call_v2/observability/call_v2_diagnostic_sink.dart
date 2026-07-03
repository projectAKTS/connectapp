import 'call_v2_diagnostic_event.dart';

abstract interface class CallV2DiagnosticSink {
  Future<void> write(CallV2DiagnosticEvent event);
}
