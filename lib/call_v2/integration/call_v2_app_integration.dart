import 'call_v2_rollout_policy.dart';
import 'disabled_call_v2_app_integration.dart';

abstract interface class CallV2AppIntegration {
  Future<void> initialize();
  Future<void> dispose();
}

Future<void> initializeCallV2AppIntegrationShellSafely() async {
  try {
    await initializeCallV2AppIntegrationShell();
  } catch (_) {
    // Call V2 startup is noncritical while the integration shell is disabled.
  }
}

Future<void> initializeCallV2AppIntegrationShell() async {
  if (!CallV2RolloutPolicy.productionEnabled) return;

  await DisabledCallV2AppIntegration().initialize();
}
