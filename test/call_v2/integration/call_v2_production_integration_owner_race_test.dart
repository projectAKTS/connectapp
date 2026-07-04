import 'package:connect_app/call_v2/call_v2_api.dart';
import 'package:connect_app/call_v2/integration/call_v2_production_integration_owner.dart';
import 'package:connect_app/call_v2/integration/call_v2_production_integration_status.dart';
import 'package:connect_app/call_v2/integration/disabled_call_v2_production_integration_owner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('concurrent initialize calls execute rollout evaluation once', () async {
    var rolloutReads = 0;
    final factory = _SpyCompositionFactory();
    final owner = DisabledCallV2ProductionIntegrationOwner(
      rolloutEnabled: () {
        rolloutReads += 1;
        return false;
      },
      compositionFactory: factory,
    );

    final futures = List<Future<void>>.generate(8, (_) => owner.initialize());
    await Future.wait(futures);

    expect(rolloutReads, 1);
    expect(factory.calls, 0);
    expect(
        owner.status.lifecycle, CallV2ProductionIntegrationLifecycle.disabled);
  });

  test('concurrent start calls coalesce to controlled rejection', () async {
    var rolloutReads = 0;
    final factory = _SpyCompositionFactory();
    final owner = DisabledCallV2ProductionIntegrationOwner(
      rolloutEnabled: () {
        rolloutReads += 1;
        return false;
      },
      compositionFactory: factory,
    );

    final results = await Future.wait<Object?>(
      List<Future<Object?>>.generate(
        6,
        (_) async {
          try {
            await owner.start();
            return null;
          } on CallV2ClientError catch (error) {
            return error.code;
          }
        },
      ),
    );

    expect(results, everyElement(CallV2ClientErrorCode.rejected));
    expect(rolloutReads, 1);
    expect(factory.calls, 0);
    expect(owner.status.runtimeStarted, isFalse);
  });

  test('stop during initialize invalidates stale completion', () async {
    final owner = DisabledCallV2ProductionIntegrationOwner();

    final initializing = owner.initialize();
    final stopping = owner.stop();
    await expectLater(
      initializing,
      throwsA(_clientError(CallV2ClientErrorCode.rejected)),
    );
    await stopping;

    expect(
        owner.status.lifecycle, CallV2ProductionIntegrationLifecycle.disabled);
    expect(owner.status.compositionConstructed, isFalse);
    expect(owner.status.runtimeStarted, isFalse);
  });

  test('dispose during initialize keeps disposed state', () async {
    final owner = DisabledCallV2ProductionIntegrationOwner();

    final initializing = owner.initialize();
    final invalidated = expectLater(
      initializing,
      throwsA(_clientError(CallV2ClientErrorCode.rejected)),
    );
    await owner.dispose();
    await invalidated;

    expect(
        owner.status.lifecycle, CallV2ProductionIntegrationLifecycle.disposed);
  });

  test('dispose during start keeps disposed state and no stale failure wins',
      () async {
    final owner = DisabledCallV2ProductionIntegrationOwner();

    final starting = owner.start();
    final invalidated = expectLater(
      starting,
      throwsA(_clientError(CallV2ClientErrorCode.rejected)),
    );
    await owner.dispose();
    await invalidated;

    expect(
        owner.status.lifecycle, CallV2ProductionIntegrationLifecycle.disposed);
    expect(owner.status.compositionConstructed, isFalse);
    expect(owner.status.runtimeStarted, isFalse);
  });

  test(
      'operations after dispose are rejected or harmless without cleanup loops',
      () async {
    final owner = DisabledCallV2ProductionIntegrationOwner();

    await owner.dispose();
    await owner.stop();
    await expectLater(
      owner.initialize(),
      throwsA(_clientError(CallV2ClientErrorCode.rejected)),
    );
    await expectLater(
      owner.start(),
      throwsA(_clientError(CallV2ClientErrorCode.rejected)),
    );
    await owner.dispose();

    expect(
        owner.status.lifecycle, CallV2ProductionIntegrationLifecycle.disposed);
  });

  test('raw rollout reader errors normalize to controlled client error',
      () async {
    final owner = DisabledCallV2ProductionIntegrationOwner(
      rolloutEnabled: () => throw StateError('raw rollout failure'),
    );

    await expectLater(
      owner.initialize(),
      throwsA(_clientError(CallV2ClientErrorCode.unavailable)),
    );

    expect(owner.status.lifecycle, CallV2ProductionIntegrationLifecycle.failed);
    expect(owner.status.errorCode, CallV2ClientErrorCode.unavailable);
    expect(owner.status.toString(), isNot(contains('raw rollout failure')));
    expect(owner.status.toString(), isNot(contains('StateError')));
  });
}

Matcher _clientError(CallV2ClientErrorCode code) {
  return isA<CallV2ClientError>().having((error) => error.code, 'code', code);
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
