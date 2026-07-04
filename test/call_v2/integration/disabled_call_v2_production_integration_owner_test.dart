import 'dart:io';

import 'package:connect_app/call_v2/call_v2_api.dart';
import 'package:connect_app/call_v2/integration/call_v2_production_integration_owner.dart';
import 'package:connect_app/call_v2/integration/call_v2_production_integration_status.dart';
import 'package:connect_app/call_v2/integration/disabled_call_v2_production_integration_owner.dart';
import 'package:connect_app/call_v2/production/call_v2_production_integration_approval.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('constructor has no side effects and retains only typed state', () {
    final factory = _SpyCompositionFactory();
    final owner = DisabledCallV2ProductionIntegrationOwner(
      compositionFactory: factory,
    );

    expect(owner.status.lifecycle,
        CallV2ProductionIntegrationLifecycle.uninitialized);
    expect(owner.status.rolloutEnabled, isFalse);
    expect(owner.status.compositionConstructed, isFalse);
    expect(owner.status.runtimeStarted, isFalse);
    expect(owner.status.routesRegistered, isFalse);
    expect(owner.status.screensAvailable, isFalse);
    expect(factory.calls, 0);
    expect(owner.compositionFactoryForTest, same(factory));
  });

  test(
      'source has no global singleton, services, navigation, routes, or screens',
      () {
    final source = _source();

    for (final forbidden in <String>[
      'static final',
      'static var',
      '.instance',
      'FirebaseAuth',
      'FirebaseFirestore',
      'FirebaseFunctions',
      'FirebaseAppCheck',
      'Permission.',
      'requestPermission',
      'RtcEngine',
      'ProductionCallV2RtcAdapter',
      'CallV2Runtime(',
      'Navigator',
      'GlobalKey',
      'BuildContext',
      'registerRoute',
      'MaterialPageRoute',
      'CupertinoPageRoute',
      'Screen',
      'Timer(',
      'periodic',
      'retry',
      'print(',
      'debugPrint',
    ]) {
      expect(source.contains(forbidden), isFalse, reason: forbidden);
    }
  });

  test('initialize transitions to disabled and remains side-effect free',
      () async {
    final factory = _SpyCompositionFactory();
    final owner = DisabledCallV2ProductionIntegrationOwner(
      compositionFactory: factory,
    );

    await owner.initialize();
    await owner.initialize();

    expect(
        owner.status.lifecycle, CallV2ProductionIntegrationLifecycle.disabled);
    expect(owner.status.errorCode, isNull);
    expect(owner.status.rolloutEnabled, isFalse);
    expect(owner.status.compositionConstructed, isFalse);
    expect(owner.status.runtimeStarted, isFalse);
    expect(owner.status.routesRegistered, isFalse);
    expect(owner.status.screensAvailable, isFalse);
    expect(factory.calls, 0);
  });

  test('concurrent initialize calls coalesce without composition construction',
      () async {
    var rolloutReads = 0;
    final factory = _SpyCompositionFactory();
    final owner = DisabledCallV2ProductionIntegrationOwner(
      rolloutEnabled: () {
        rolloutReads += 1;
        return false;
      },
      compositionFactory: factory,
    );

    final first = owner.initialize();
    final second = owner.initialize();
    await Future.wait(<Future<void>>[first, second]);

    expect(rolloutReads, 1);
    expect(factory.calls, 0);
    expect(
        owner.status.lifecycle, CallV2ProductionIntegrationLifecycle.disabled);
  });

  test('start returns controlled rejected error and performs no work',
      () async {
    final factory = _SpyCompositionFactory();
    final owner = DisabledCallV2ProductionIntegrationOwner(
      compositionFactory: factory,
    );

    await expectLater(
      owner.start(),
      throwsA(_clientError(CallV2ClientErrorCode.rejected)),
    );
    await expectLater(
      owner.start(),
      throwsA(_clientError(CallV2ClientErrorCode.rejected)),
    );

    expect(
        owner.status.lifecycle, CallV2ProductionIntegrationLifecycle.disabled);
    expect(owner.status.errorCode, CallV2ClientErrorCode.rejected);
    expect(owner.status.compositionConstructed, isFalse);
    expect(owner.status.runtimeStarted, isFalse);
    expect(owner.status.routesRegistered, isFalse);
    expect(owner.status.screensAvailable, isFalse);
    expect(factory.calls, 0);
  });

  test('fully approved human approvals with rollout false remain inert',
      () async {
    final factory = _SpyCompositionFactory();
    final owner = DisabledCallV2ProductionIntegrationOwner(
      approval: const CallV2ProductionIntegrationApproval.fullyApproved(),
      compositionFactory: factory,
    );

    await owner.initialize();

    expect(
        owner.status.lifecycle, CallV2ProductionIntegrationLifecycle.disabled);
    expect(owner.status.rolloutEnabled, isFalse);
    expect(owner.status.compositionConstructed, isFalse);
    expect(owner.status.runtimeStarted, isFalse);
    expect(factory.calls, 0);
  });

  test('stop before initialize and repeated stop are safe', () async {
    final owner = DisabledCallV2ProductionIntegrationOwner();

    await owner.stop();
    await owner.stop();

    expect(
        owner.status.lifecycle, CallV2ProductionIntegrationLifecycle.disabled);
    expect(owner.status.compositionConstructed, isFalse);
    expect(owner.status.runtimeStarted, isFalse);
  });

  test('dispose is idempotent and rejects future initialize or start',
      () async {
    final owner = DisabledCallV2ProductionIntegrationOwner();

    await owner.dispose();
    await owner.dispose();
    await owner.stop();

    expect(
        owner.status.lifecycle, CallV2ProductionIntegrationLifecycle.disposed);
    await expectLater(
      owner.initialize(),
      throwsA(_clientError(CallV2ClientErrorCode.rejected)),
    );
    await expectLater(
      owner.start(),
      throwsA(_clientError(CallV2ClientErrorCode.rejected)),
    );
  });
}

Matcher _clientError(CallV2ClientErrorCode code) {
  return isA<CallV2ClientError>().having((error) => error.code, 'code', code);
}

String _source() {
  return <String>[
    'lib/call_v2/integration/call_v2_production_integration_owner.dart',
    'lib/call_v2/integration/call_v2_production_integration_status.dart',
    'lib/call_v2/integration/disabled_call_v2_production_integration_owner.dart',
  ].map((path) => File(path).readAsStringSync()).join('\n');
}

final class _SpyCompositionFactory
    implements CallV2ProductionIntegrationCompositionFactory {
  var calls = 0;

  @override
  Object createProductionComposition() {
    calls += 1;
    return Object();
  }
}
