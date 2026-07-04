import 'call_v2_app_integration.dart';
import 'call_v2_production_integration_owner.dart';
import 'disabled_call_v2_production_integration_owner.dart';

final class DisabledCallV2AppIntegration implements CallV2AppIntegration {
  DisabledCallV2AppIntegration({
    CallV2ProductionIntegrationOwner? owner,
  }) : _owner = owner ?? DisabledCallV2ProductionIntegrationOwner();

  final CallV2ProductionIntegrationOwner _owner;

  @override
  Future<void> initialize() => _owner.initialize();

  @override
  Future<void> dispose() => _owner.dispose();
}
