import 'call_v2_diagnostic_event.dart';
import 'call_v2_diagnostic_sink.dart';
import 'call_v2_observability.dart';

class ProductionCallV2Observer implements CallV2Observer {
  const ProductionCallV2Observer({
    required CallV2DiagnosticSink sink,
    required bool Function() isEnabled,
  })  : _sink = sink,
        _isEnabled = isEnabled;

  final CallV2DiagnosticSink _sink;
  final bool Function() _isEnabled;

  @override
  Future<void> record(CallV2DiagnosticEvent event) async {
    if (!_isEnabled()) return;

    try {
      await _sink.write(event);
    } catch (_) {
      // Observability is best-effort and must never affect call behavior.
    }
  }
}
