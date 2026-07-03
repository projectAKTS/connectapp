import 'call_v2_app_integration.dart';

final class DisabledCallV2AppIntegration implements CallV2AppIntegration {
  const DisabledCallV2AppIntegration();

  @override
  Future<void> initialize() async {}

  @override
  Future<void> dispose() async {}
}
