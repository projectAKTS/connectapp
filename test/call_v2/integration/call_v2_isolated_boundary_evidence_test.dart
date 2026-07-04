import 'dart:io';

import 'package:connect_app/call_v2/integration/call_v2_isolated_boundary_evidence.dart';
import 'package:connect_app/call_v2/integration/call_v2_route_sink.dart';
import 'package:connect_app/call_v2/integration/non_production/non_production_call_v2_navigator_route_sink.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('accepted isolated boundary evidence is derived from Type references',
      () {
    final evidence = buildCallV2IsolatedBoundaryEvidence();

    expect(evidence.routeFactoryAvailable, isTrue);
    expect(evidence.presentationAdapterAvailable, isTrue);
    expect(evidence.integrationHarnessAvailable, isTrue);
    expect(evidence.widgetNavigationBoundaryAvailable, isTrue);
  });

  test('widget navigation boundary uses the accepted route sink pair', () {
    const typeEvidence = CallV2IsolatedBoundaryTypeEvidence();

    expect(typeEvidence.widgetNavigationContract, CallV2RouteSink);
    expect(
      typeEvidence.widgetNavigationImplementation,
      NonProductionCallV2NavigatorRouteSink,
    );
  });

  test('source references concrete widget sink without construction', () {
    final source = File(
      'lib/call_v2/integration/call_v2_isolated_boundary_evidence.dart',
    ).readAsStringSync();

    expect(source, contains('CallV2RouteSink'));
    expect(source, contains('NonProductionCallV2NavigatorRouteSink'));
    expect(source, contains('widgetNavigationContract == CallV2RouteSink'));
    expect(
      source,
      contains(
        'widgetNavigationImplementation ==\n'
        '                NonProductionCallV2NavigatorRouteSink',
      ),
    );
    expect(source.contains('NonProductionCallV2NavigatorRouteSink('), isFalse);
    expect(source.contains('.fromNavigatorKey('), isFalse);
    expect(source.contains('GlobalKey'), isFalse);
    expect(source.contains('Navigator.'), isFalse);
    expect(source.contains('Navigator('), isFalse);
    expect(source.contains('.push'), isFalse);
    expect(source.contains('.pop'), isFalse);
    expect(source.contains('.removeRoute'), isFalse);
  });
}
