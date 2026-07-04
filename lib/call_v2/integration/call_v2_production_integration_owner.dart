import 'call_v2_production_integration_status.dart';

abstract interface class CallV2ProductionIntegrationOwner {
  CallV2ProductionIntegrationStatus get status;

  Future<void> initialize();
  Future<void> start();
  Future<void> stop();
  Future<void> dispose();
}

abstract interface class CallV2ProductionIntegrationCompositionFactory {
  Object createProductionComposition();
}
