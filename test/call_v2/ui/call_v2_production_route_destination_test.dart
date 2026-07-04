import 'dart:io';

import 'package:connect_app/call_v2/ui/call_v2_production_route_contract.dart';
import 'package:connect_app/call_v2/ui/call_v2_production_route_destination.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every production destination is represented and typed', () {
    expect(
      CallV2ProductionRouteDestination.values,
      containsAll(<CallV2ProductionRouteDestination>[
        CallV2ProductionRouteDestination.connecting,
        CallV2ProductionRouteDestination.activeAudio,
        CallV2ProductionRouteDestination.activeVideo,
        CallV2ProductionRouteDestination.controlledFailure,
        CallV2ProductionRouteDestination.incomingReviewReserved,
      ]),
    );
  });

  test('incoming review is reserved and unavailable', () {
    expect(
      CallV2ProductionRouteDestination.incomingReviewReserved.isAvailable,
      isFalse,
    );
    expect(
      () => CallV2ProductionRouteNames.forDestination(
        CallV2ProductionRouteDestination.incomingReviewReserved,
      ),
      throwsArgumentError,
    );
  });

  test('fixed route names are identifier free and have no query parameters',
      () {
    const contract = CallV2FixedProductionRouteContract();
    final names = <String>[
      contract.routeNameFor(CallV2ProductionRouteDestination.connecting),
      contract.routeNameFor(CallV2ProductionRouteDestination.activeAudio),
      contract.routeNameFor(CallV2ProductionRouteDestination.activeVideo),
      contract.routeNameFor(CallV2ProductionRouteDestination.controlledFailure),
    ];

    expect(names, <String>[
      '/call-v2/connecting',
      '/call-v2/audio',
      '/call-v2/video',
      '/call-v2/failure',
    ]);
    for (final name in names) {
      expect(name, isNot(contains('?')));
      expect(name, isNot(contains('=')));
      expect(name, isNot(contains('uid')));
      expect(name, isNot(contains('callId')));
      expect(name, isNot(contains('token')));
      expect(name, isNot(contains('channel')));
    }
  });

  test('production route contract has no Flutter route dependencies', () {
    final source = File(
      'lib/call_v2/ui/call_v2_production_route_contract.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('package:flutter')));
    expect(source, isNot(contains('Widget')));
    expect(source, isNot(contains('Route<')));
    expect(source, isNot(contains('BuildContext')));
    expect(source, isNot(contains('Navigator')));
  });

  test('route destination source has no dynamic concatenation or arguments',
      () {
    final source = File(
      'lib/call_v2/ui/call_v2_production_route_destination.dart',
    ).readAsStringSync();

    expect(source, isNot(contains(r'${')));
    expect(source, isNot(contains('RouteSettings')));
    expect(source, isNot(contains('arguments')));
    expect(source, isNot(contains('credentials')));
    expect(source, isNot(contains('Firebase')));
    expect(source, isNot(contains('Rtc')));
  });
}
