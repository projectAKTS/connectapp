import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:connect_app/screens/call/agora_call_screen.dart';
import 'package:connect_app/services/call_session_manager.dart';
import 'package:connect_app/services/callkit_id.dart';
import 'package:connect_app/services/helperly_test_runtime.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const callerUid = 'exact_owner_caller';
  const calleeUid = 'exact_owner_callee';
  const exactA = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
  const exactB = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
  const exactC = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';

  late FakeFirebaseFirestore firestore;
  late CallSessionManager manager;

  Future<void> seedInvite(
    String inviteId, {
    CallInviteStatus status = CallInviteStatus.ringing,
  }) async {
    await firestore.collection('callInvites').doc(inviteId).set({
      'fromUid': callerUid,
      'fromName': 'Exact Caller',
      'toUid': calleeUid,
      'toName': 'Exact Callee',
      'channel': 'channel_$inviteId',
      'isVideo': true,
      'status': status.name,
      'createdAt': Timestamp.now(),
      'callerStage': status.name,
      'calleeStage': status.name,
    });
  }

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    HelperlyTestRuntime.configureForTest(
      firestore: firestore,
      currentUid: calleeUid,
      currentDisplayName: 'Exact Callee',
    );
    manager = CallSessionManager.instance;
    await manager.clearForSignedOut();
    await manager.forceIdleForTest();
    HelperlyTestRuntime.configureForTest(
      firestore: firestore,
      currentUid: calleeUid,
      currentDisplayName: 'Exact Callee',
    );
  });

  tearDown(() async {
    await manager.forceIdleForTest();
    HelperlyTestRuntime.clear();
  });

  test('accepted screen ownership chooses exact UUID over normalized fallback',
      () {
    final fallback = normalizeCallkitId(
      rawId: 'shared_invite',
      fallback: 'shared_channel',
    );
    final ownership = CallV2ScreenCallkitOwnership(
      acceptedCallkitId: exactA,
      inviteId: 'shared_invite',
      channel: 'shared_channel',
    );

    expect(exactA, isNot(fallback));
    expect(ownership.ownedCallkitId, exactA);
    expect(ownership.hasExactAcceptedIdentity, isTrue);
  });

  test('legacy screen ownership preserves normalized fallback', () {
    final ownership = CallV2ScreenCallkitOwnership(
      acceptedCallkitId: '',
      inviteId: 'legacy_invite',
      channel: 'legacy_channel',
    );

    expect(
      ownership.ownedCallkitId,
      normalizeCallkitId(
        rawId: 'legacy_invite',
        fallback: 'legacy_channel',
      ),
    );
    expect(ownership.hasExactAcceptedIdentity, isFalse);
  });

  test('accepted incoming setup skips synthetic plugin connected action',
      () async {
    final pluginConnected = <String>[];
    final controller = CallV2ScreenCallkitController(
      ownership: CallV2ScreenCallkitOwnership(
        acceptedCallkitId: exactA,
        inviteId: 'invite_a',
        channel: 'channel_a',
      ),
      markPluginConnected: (id) async => pluginConnected.add(id),
      endPluginCall: (_) async {},
      endExactNativeCall: (_) async => true,
    );

    expect(await controller.markConnectedAfterRtcJoin(), isFalse);
    expect(pluginConnected, isEmpty);
  });

  test('legacy connected marker remains available after RTC join', () async {
    final pluginConnected = <String>[];
    final controller = CallV2ScreenCallkitController(
      ownership: CallV2ScreenCallkitOwnership(
        acceptedCallkitId: '',
        inviteId: 'legacy_invite',
        channel: 'legacy_channel',
      ),
      markPluginConnected: (id) async => pluginConnected.add(id),
      endPluginCall: (_) async {},
      endExactNativeCall: (_) async => true,
    );

    expect(await controller.markConnectedAfterRtcJoin(), isTrue);
    expect(pluginConnected, [controller.ownership.ownedCallkitId]);
  });

  test('normal cleanup uses exact native end and never plugin global state',
      () async {
    var simulatedPluginGlobalId = exactB;
    final nativeEnds = <String>[];
    final pluginEnds = <String>[];
    final controller = CallV2ScreenCallkitController(
      ownership: CallV2ScreenCallkitOwnership(
        acceptedCallkitId: exactA,
        inviteId: 'invite_a',
        channel: 'channel_a',
      ),
      markPluginConnected: (_) async {},
      endPluginCall: (id) async => pluginEnds.add(id),
      endExactNativeCall: (id) async {
        nativeEnds.add(id);
        return true;
      },
    );

    expect(await controller.endOwnedCall(useExactNativeEnd: true), isTrue);
    expect(nativeEnds, [exactA]);
    expect(pluginEnds, isEmpty);
    expect(simulatedPluginGlobalId, exactB);
    simulatedPluginGlobalId = exactB;
    expect(simulatedPluginGlobalId, exactB);
  });

  test('A B C screen cleanup remains exact and sequential', () async {
    final ended = <String>[];
    for (final exactId in [exactA, exactB, exactC]) {
      final controller = CallV2ScreenCallkitController(
        ownership: CallV2ScreenCallkitOwnership(
          acceptedCallkitId: exactId,
          inviteId: 'same_invite',
          channel: 'same_channel',
        ),
        markPluginConnected: (_) async {},
        endPluginCall: (_) async {},
        endExactNativeCall: (id) async {
          ended.add(id);
          return true;
        },
      );
      await controller.endOwnedCall(useExactNativeEnd: true);
    }

    expect(ended, [exactA, exactB, exactC]);
  });

  test('normal Agora screen cleanup has no process-wide end operation', () {
    final source = File(
      'lib/screens/call/agora_call_screen.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('FlutterCallkitIncoming.endAllCalls()')));
    expect(source, isNot(contains('FlutterCallkitIncoming.activeCalls()')));
  });

  testWidgets('exact accepted UUID reaches route recorder and route ACK',
      (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    final openedExactIds = <String>[];
    final acknowledged = <String>[];
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigatorKey,
      home: const Scaffold(body: Text('home')),
    ));
    await seedInvite('route_exact');
    manager.configure(
      navigatorKey: navigatorKey,
      appForegroundProvider: () async => true,
      listNativeCalls: () async => const <NativeCallSnapshot>[
        NativeCallSnapshot(
          callkitId: exactA,
          inviteId: 'route_exact',
          channel: 'channel_route_exact',
          accepted: true,
        ),
      ],
      endNativeCall: (_) async {},
      acknowledgeNativeRouteOwnership: (id) async {
        acknowledged.add(id);
        return true;
      },
      callScreenOpenRecorderForTest: ({
        required String inviteId,
        required String channel,
        required String acceptedCallkitId,
        required bool isVideo,
        required String otherUserName,
        required String? otherUserId,
        required bool isCaller,
        required connectionSystem,
        required bool callV2FallbackUsed,
        required String callV2BlockerCode,
      }) async {
        openedExactIds.add(acceptedCallkitId);
      },
      skipActiveInviteBindingForTest: true,
      skipAcceptedNativeWatchBindingForTest: true,
    );

    final result = await manager.handleRecoveredAcceptedInvite(
      inviteId: 'route_exact',
      channel: 'channel_route_exact',
      isVideo: true,
      fromName: 'Exact Caller',
      fromUid: callerUid,
      callkitId: exactA,
    );
    await tester.pump();

    expect(result, AcceptedCallRecoveryResult.opened);
    expect(openedExactIds, [exactA]);
    expect(acknowledged, [exactA]);

    await manager.forceIdleForTest();
    await tester.pump();
  });

  testWidgets(
      'delayed A hard reset protects accepted B and cleans terminal orphan C',
      (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigatorKey,
      home: const Scaffold(body: Text('home')),
    ));
    await seedInvite('invite_b');
    await seedInvite('orphan_c', status: CallInviteStatus.ended);
    await manager.debugCreateHeldCallRouteForTest(
      inviteId: 'invite_a',
      channel: 'channel_invite_a',
      acceptedCallkitId: exactA,
    );
    await manager.debugMarkHeldRouteTerminalForTest('invite_a');

    final nativeCalls = <NativeCallSnapshot>[
      const NativeCallSnapshot(
        callkitId: exactA,
        inviteId: 'invite_a',
        channel: 'channel_invite_a',
        accepted: true,
      ),
      const NativeCallSnapshot(
        callkitId: exactC,
        inviteId: 'orphan_c',
        channel: 'channel_orphan_c',
      ),
    ];
    final ended = <String>[];
    final cleared = <String>[];
    final aEndStarted = Completer<void>();
    final releaseAEnd = Completer<void>();
    manager.configure(
      navigatorKey: navigatorKey,
      appForegroundProvider: () async => true,
      listNativeCalls: () async => List<NativeCallSnapshot>.of(nativeCalls),
      endNativeCall: (id) async {
        if (id == exactA && !aEndStarted.isCompleted) {
          aEndStarted.complete();
          await releaseAEnd.future;
        }
        ended.add(id);
        nativeCalls.removeWhere((call) => call.callkitId == id);
      },
      clearStoredAcceptedCallRecovery: ({
        required String inviteId,
        required String callkitId,
      }) async {
        cleared.add(callkitId);
      },
      skipAcceptedNativeWatchBindingForTest: true,
    );

    expect(
      await manager.handleRecoveredAcceptedInvite(
        inviteId: 'invite_b',
        channel: 'channel_invite_b',
        isVideo: true,
        fromName: 'Exact Caller',
        fromUid: callerUid,
        callkitId: exactB,
      ),
      AcceptedCallRecoveryResult.pendingTeardown,
    );

    final reset = manager.hardResetForNewCall(
      reason: 'exact_owner_a_cleanup',
      expectedInviteId: 'invite_a',
      expectedCallkitId: exactA,
    );
    await aEndStarted.future;
    nativeCalls.add(const NativeCallSnapshot(
      callkitId: exactB,
      inviteId: 'invite_b',
      channel: 'channel_invite_b',
      accepted: true,
    ));
    releaseAEnd.complete();
    await reset;

    expect(ended, containsAll(<String>[exactA, exactC]));
    expect(ended, isNot(contains(exactB)));
    expect(nativeCalls.any((call) => call.callkitId == exactB), isTrue);
    expect(cleared, [exactA]);
    expect(manager.debugSnapshot()['pendingAcceptedIntent'], isTrue);

    await manager.forceIdleForTest();
    await tester.pump();
  });

  testWidgets('stale A cleanup request cannot reset newer B session',
      (tester) async {
    await manager.debugCreateHeldCallRouteForTest(
      inviteId: 'invite_b',
      channel: 'channel_invite_b',
      acceptedCallkitId: exactB,
    );
    final ended = <String>[];
    manager.configure(endNativeCall: (id) async => ended.add(id));

    await manager.hardResetForNewCall(
      reason: 'late_a_completion',
      expectedInviteId: 'invite_a',
      expectedCallkitId: exactA,
    );

    expect(manager.activeInviteId, 'invite_b');
    expect(ended, isEmpty);
  });

  testWidgets(
      'blocked exact A end releases lifecycle and late completion preserves B',
      (tester) async {
    final endStarted = Completer<void>();
    final releaseEnd = Completer<void>();
    final ended = <String>[];
    final cleared = <String>[];
    manager.configure(
      endNativeCall: (id) async {
        ended.add(id);
        if (id == exactA) {
          if (!endStarted.isCompleted) endStarted.complete();
          await releaseEnd.future;
        }
      },
      clearStoredAcceptedCallRecovery: ({
        required String inviteId,
        required String callkitId,
      }) async {
        cleared.add(callkitId);
      },
    );
    await manager.debugCreateHeldCallRouteForTest(
      inviteId: 'blocked_end_a',
      channel: 'channel_blocked_end_a',
      acceptedCallkitId: exactA,
    );
    await manager.debugMarkHeldRouteTerminalForTest('blocked_end_a');

    var closeCompleted = false;
    final closeA = manager.debugCloseHeldRouteForTest('blocked_end_a');
    unawaited(closeA.whenComplete(() => closeCompleted = true));
    await endStarted.future;
    for (var attempt = 0;
        attempt < 10 && manager.debugSnapshot()['callLifecycleState'] != 'idle';
        attempt += 1) {
      await tester.pump();
    }

    expect(manager.debugSnapshot()['callLifecycleState'], 'idle');
    expect(closeCompleted, isFalse);
    final bGeneration = await manager.debugCreateHeldCallRouteForTest(
      inviteId: 'blocked_end_b',
      channel: 'channel_blocked_end_b',
      acceptedCallkitId: exactB,
    );
    expect(manager.activeInviteId, 'blocked_end_b');
    expect(manager.debugSnapshot()['lifecycleGeneration'], bGeneration);
    expect(manager.debugSnapshot()['callLifecycleState'], 'connected');
    expect(manager.debugSnapshot()['callRouteActive'], isTrue);

    releaseEnd.complete();
    await closeA;
    await tester.pump();

    expect(ended, [exactA]);
    expect(cleared, [exactA]);
    expect(manager.activeInviteId, 'blocked_end_b');
    expect(manager.debugSnapshot()['lifecycleGeneration'], bGeneration);
    expect(manager.debugSnapshot()['callLifecycleState'], 'connected');
    expect(manager.debugSnapshot()['callRouteActive'], isTrue);
  });

  testWidgets('blocked exact A stored recovery clear does not block or clear B',
      (tester) async {
    final clearStarted = Completer<void>();
    final releaseClear = Completer<void>();
    final ended = <String>[];
    final cleared = <String>[];
    manager.configure(
      endNativeCall: (id) async => ended.add(id),
      clearStoredAcceptedCallRecovery: ({
        required String inviteId,
        required String callkitId,
      }) async {
        cleared.add(callkitId);
        if (callkitId == exactA) {
          if (!clearStarted.isCompleted) clearStarted.complete();
          await releaseClear.future;
        }
      },
    );
    await manager.debugCreateHeldCallRouteForTest(
      inviteId: 'blocked_clear_a',
      channel: 'channel_blocked_clear_a',
      acceptedCallkitId: exactA,
    );
    await manager.debugMarkHeldRouteTerminalForTest('blocked_clear_a');

    var closeCompleted = false;
    final closeA = manager.debugCloseHeldRouteForTest('blocked_clear_a');
    unawaited(closeA.whenComplete(() => closeCompleted = true));
    await clearStarted.future;
    for (var attempt = 0;
        attempt < 10 && manager.debugSnapshot()['callLifecycleState'] != 'idle';
        attempt += 1) {
      await tester.pump();
    }

    expect(manager.debugSnapshot()['callLifecycleState'], 'idle');
    expect(closeCompleted, isFalse);
    final bGeneration = await manager.debugCreateHeldCallRouteForTest(
      inviteId: 'blocked_clear_b',
      channel: 'channel_blocked_clear_b',
      acceptedCallkitId: exactB,
    );
    expect(manager.activeInviteId, 'blocked_clear_b');

    releaseClear.complete();
    await closeA;
    await tester.pump();

    expect(ended, [exactA]);
    expect(cleared, [exactA]);
    expect(manager.activeInviteId, 'blocked_clear_b');
    expect(manager.debugSnapshot()['lifecycleGeneration'], bGeneration);
    expect(manager.debugSnapshot()['callLifecycleState'], 'connected');
    expect(manager.debugSnapshot()['callRouteActive'], isTrue);
  });

  testWidgets('pending incoming is claimed before deferred A cleanup settles',
      (tester) async {
    final endStarted = Completer<void>();
    final releaseEnd = Completer<void>();
    manager.configure(
      listNativeCalls: () async => const <NativeCallSnapshot>[
        NativeCallSnapshot(
          callkitId: exactB,
          inviteId: 'pending_owner_b',
          channel: 'channel_pending_owner_b',
        ),
      ],
      endNativeCall: (id) async {
        if (id == exactA) {
          if (!endStarted.isCompleted) endStarted.complete();
          await releaseEnd.future;
        }
      },
      clearStoredAcceptedCallRecovery: ({
        required String inviteId,
        required String callkitId,
      }) async {},
    );
    await manager.debugCreateHeldCallRouteForTest(
      inviteId: 'pending_owner_a',
      channel: 'channel_pending_owner_a',
      acceptedCallkitId: exactA,
    );
    await manager.debugMarkHeldRouteTerminalForTest('pending_owner_a');
    await seedInvite('pending_owner_b');
    await manager.handleNotificationInviteTap(
      inviteId: 'pending_owner_b',
      channel: 'channel_pending_owner_b',
      isVideo: true,
      fromName: 'Exact Caller',
      fromUid: callerUid,
      source: 'pending_priority_test',
    );
    expect(manager.debugSnapshot()['pendingIncomingPresent'], isTrue);

    final closeA = manager.debugCloseHeldRouteForTest('pending_owner_a');
    await endStarted.future;
    for (var attempt = 0;
        attempt < 10 &&
            manager.debugSnapshot()['callLifecycleState'] != 'incomingPrompt';
        attempt += 1) {
      await tester.pump();
    }

    expect(manager.debugSnapshot()['callLifecycleState'], 'incomingPrompt');
    expect(manager.debugSnapshot()['pendingIncomingPresent'], isFalse);
    expect(
        manager.debugSnapshot()['pendingClaimTransferredAtomically'], isTrue);
    await expectLater(
      manager.debugCreateHeldCallRouteForTest(
        inviteId: 'outgoing_must_not_steal',
        channel: 'channel_outgoing_must_not_steal',
        acceptedCallkitId: exactC,
      ),
      throwsA(isA<StateError>()),
    );

    releaseEnd.complete();
    await tester.pump(const Duration(milliseconds: 300));
    await closeA;
    expect(manager.debugSnapshot()['callLifecycleState'], 'incomingPrompt');
  });

  testWidgets('normal teardown performs exact cleanup and reaches idle',
      (tester) async {
    final ended = <String>[];
    final cleared = <String>[];
    manager.configure(
      endNativeCall: (id) async => ended.add(id),
      clearStoredAcceptedCallRecovery: ({
        required String inviteId,
        required String callkitId,
      }) async {
        cleared.add(callkitId);
      },
    );
    await manager.debugCreateHeldCallRouteForTest(
      inviteId: 'normal_teardown_a',
      channel: 'channel_normal_teardown_a',
      acceptedCallkitId: exactA,
    );
    await manager.debugMarkHeldRouteTerminalForTest('normal_teardown_a');

    await manager.debugCloseHeldRouteForTest('normal_teardown_a');
    await tester.pump();

    expect(ended, [exactA]);
    expect(cleared, [exactA]);
    expect(manager.activeInviteId, isNull);
    expect(manager.debugSnapshot()['callLifecycleState'], 'idle');
    expect(manager.debugSnapshot()['callRouteActive'], isFalse);
  });
}
