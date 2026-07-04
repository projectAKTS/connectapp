import 'call_v2_presentation_adapter.dart';
import 'call_v2_route_factory.dart';
import 'call_v2_route_sink.dart';
import 'call_v2_test_harness.dart';
import 'non_production/non_production_call_v2_navigator_route_sink.dart';
import 'non_production_call_v2_presentation_adapter.dart';
import 'non_production_call_v2_route_factory.dart';
import 'non_production_call_v2_test_harness.dart';

final class CallV2IsolatedBoundaryEvidence {
  const CallV2IsolatedBoundaryEvidence({
    required this.routeFactoryAvailable,
    required this.presentationAdapterAvailable,
    required this.integrationHarnessAvailable,
    required this.widgetNavigationBoundaryAvailable,
  });

  final bool routeFactoryAvailable;
  final bool presentationAdapterAvailable;
  final bool integrationHarnessAvailable;
  final bool widgetNavigationBoundaryAvailable;
}

CallV2IsolatedBoundaryEvidence buildCallV2IsolatedBoundaryEvidence({
  CallV2IsolatedBoundaryTypeEvidence typeEvidence =
      const CallV2IsolatedBoundaryTypeEvidence(),
}) {
  return CallV2IsolatedBoundaryEvidence(
    routeFactoryAvailable:
        typeEvidence.routeFactoryContract == CallV2RouteFactory &&
            typeEvidence.routeFactoryImplementation ==
                NonProductionCallV2RouteFactory,
    presentationAdapterAvailable:
        typeEvidence.presentationAdapterContract == CallV2PresentationAdapter &&
            typeEvidence.presentationAdapterImplementation ==
                NonProductionCallV2PresentationAdapter,
    integrationHarnessAvailable:
        typeEvidence.integrationHarnessContract == CallV2TestHarness &&
            typeEvidence.integrationHarnessImplementation ==
                NonProductionCallV2TestHarness,
    widgetNavigationBoundaryAvailable:
        typeEvidence.widgetNavigationContract == CallV2RouteSink &&
            typeEvidence.widgetNavigationImplementation ==
                NonProductionCallV2NavigatorRouteSink,
  );
}

final class CallV2IsolatedBoundaryTypeEvidence {
  const CallV2IsolatedBoundaryTypeEvidence();

  Type get routeFactoryContract => CallV2RouteFactory;
  Type get routeFactoryImplementation => NonProductionCallV2RouteFactory;
  Type get presentationAdapterContract => CallV2PresentationAdapter;
  Type get presentationAdapterImplementation =>
      NonProductionCallV2PresentationAdapter;
  Type get integrationHarnessContract => CallV2TestHarness;
  Type get integrationHarnessImplementation => NonProductionCallV2TestHarness;
  Type get widgetNavigationContract => CallV2RouteSink;
  Type get widgetNavigationImplementation =>
      NonProductionCallV2NavigatorRouteSink;
}
