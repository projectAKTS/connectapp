import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:connect_app/services/call_invite_signaling.dart';
import 'package:connect_app/services/call_session_manager.dart';
import 'package:connect_app/services/callkit_id.dart';
import 'package:connect_app/services/helperly_test_runtime.dart';
import 'package:connect_app/services/notification_service.dart';

/// Reproduces the physical 2026-10-26 failure mode: the iOS Firestore client
/// wedged its worker queue, so every transaction hung forever while plain
/// reads and listeners still answered from the local client.
class _WedgeableFirestore extends FakeFirebaseFirestore {
  bool transactionsWedged = false;
  int transactionsStarted = 0;

  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> transactionHandler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) {
    transactionsStarted += 1;
    if (transactionsWedged) return Completer<T>().future;
    return super.runTransaction(
      transactionHandler,
      timeout: timeout,
      maxAttempts: maxAttempts,
    );
  }
}

/// Contract fake for the `callInviteTransition` callable (the server logic
/// is covered by connect_functions/test/call_invites). It writes with plain
/// document sets, which never touch the wedged transaction path.
class _FakeCallInviteSignaling implements CallInviteSignaling {
  _FakeCallInviteSignaling(this.db, this.uid);

  final FakeFirebaseFirestore db;
  final String uid;
  final List<String> actions = <String>[];
  bool available = true;

  static const _terminal = <String>{
    'declined',
    'missed',
    'cancelled',
    'ended',
    'failed',
  };

  @override
  Future<Map<String, dynamic>?> transition(
    String action,
    Map<String, Object?> data,
  ) async {
    actions.add(action);
    if (!available) return null;
    final ref = db.collection('callInvites').doc(data['inviteId']! as String);
    final current = (await ref.get()).data();
    if (current == null) return <String, dynamic>{'decision': 'missing'};
    final status = (current['status'] ?? '').toString();
    final isCaller = current['fromUid'] == uid;
    switch (action) {
      case 'accept':
        if (current['toUid'] != uid) {
          return <String, dynamic>{'decision': 'wrongRecipient'};
        }
        if (_terminal.contains(status)) {
          return <String, dynamic>{
            'decision': 'terminal',
            'invite': <String, dynamic>{...current},
          };
        }
        if (status == 'ringing') {
          await ref.set(<String, dynamic>{
            'status': 'accepted',
            'calleeStage': 'accepted',
          }, SetOptions(merge: true));
          return <String, dynamic>{
            'decision': 'accepted',
            'invite': <String, dynamic>{...current, 'status': 'accepted'},
          };
        }
        return <String, dynamic>{
          'decision': 'alreadyAccepted',
          'invite': <String, dynamic>{...current},
        };
      case 'stage':
        if (_terminal.contains(status)) {
          return <String, dynamic>{'applied': false, 'status': status};
        }
        final stage = data['stage']! as String;
        await ref.set(<String, dynamic>{
          '${isCaller ? 'caller' : 'callee'}Stage': stage,
          if (stage == 'joining' && !isCaller) 'status': 'joining',
          if (stage == 'connected') 'status': 'connected',
        }, SetOptions(merge: true));
        return <String, dynamic>{'applied': true, 'status': status};
      case 'terminal':
        if (_terminal.contains(status)) {
          return <String, dynamic>{
            'status': status,
            'endReason': current['endReason'],
            'writeApplied': false,
            'preservedExistingTerminal': true,
          };
        }
        final effective = data['authoritativeLocalExit'] == true
            ? (isCaller && status == 'ringing' ? 'cancelled' : 'ended')
            : data['requestedStatus']! as String;
        await ref.set(<String, dynamic>{
          'status': effective,
          'endReason': data['endReason'],
          'endedBy': uid,
        }, SetOptions(merge: true));
        return <String, dynamic>{
          'status': effective,
          'endReason': data['endReason'],
          'writeApplied': true,
          'preservedExistingTerminal': false,
        };
      case 'decline':
        if (status != 'ringing') {
          return <String, dynamic>{'applied': false, 'status': status};
        }
        await ref.set(<String, dynamic>{
          'status': 'declined',
          'endReason': data['endReason'],
        }, SetOptions(merge: true));
        return <String, dynamic>{'applied': true, 'status': 'declined'};
    }
    return null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const callerUid = 'notify_caller';
  const calleeUid = 'notify_callee';

  late _WedgeableFirestore firestore;
  late CallSessionManager manager;
  late NotificationService notifications;
  late _FakeCallInviteSignaling signaling;
  late List<String> opened;

  String exactId(String inviteId) =>
      normalizeCallkitId(rawId: inviteId, fallback: 'channel_$inviteId');

  Future<void> seedRinging(String inviteId) {
    return firestore.collection('callInvites').doc(inviteId).set({
      'fromUid': callerUid,
      'fromName': 'Notify Caller',
      'toUid': calleeUid,
      'toName': 'Notify Callee',
      'channel': 'channel_$inviteId',
      'isVideo': false,
      'status': CallInviteStatus.ringing.name,
      'createdAt': Timestamp.now(),
    });
  }

  Future<String?> status(String inviteId) async =>
      (await firestore.collection('callInvites').doc(inviteId).get())
          .data()?['status'] as String?;

  /// Drives [future] with simulated time. Awaiting a manager call directly
  /// inside `testWidgets` would deadlock on its bounded timeouts.
  Future<void> pumped(
    WidgetTester tester,
    Future<void> future, {
    Duration max = const Duration(seconds: 30),
  }) async {
    var done = false;
    Object? error;
    future.then((_) => done = true, onError: (Object e) {
      error = e;
      done = true;
    });
    for (var i = 0; i < max.inMilliseconds ~/ 100 && !done; i += 1) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    if (!done) fail('operation did not complete within $max simulated time');
    if (error != null) throw error!;
  }

  Future<void> pumpFor(WidgetTester tester, Duration duration) async {
    for (var i = 0; i < duration.inMilliseconds ~/ 100; i += 1) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> start(WidgetTester tester, {required bool withSignaling}) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    opened = <String>[];
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigatorKey,
      home: const Scaffold(body: Text('home')),
    ));
    notifications = NotificationService();
    notifications.debugBeginPushBindingForTest(calleeUid);
    signaling = _FakeCallInviteSignaling(firestore, calleeUid);
    manager.configure(
      navigatorKey: navigatorKey,
      listNativeCalls: () async => const <NativeCallSnapshot>[],
      endNativeCall: (_) async {},
      appForegroundProvider: () async => true,
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
        opened.add(inviteId);
      },
      skipActiveInviteBindingForTest: true,
      iosCallkitOnlyIncomingUiForTest: true,
      callInviteSignalingForTest: withSignaling ? signaling : null,
    );
  }

  Future<void> nativeAccept(String inviteId) {
    return notifications.debugSimulateNativeAcceptedCallkitBridgeForTest(
      inviteId: inviteId,
      channel: 'channel_$inviteId',
      isVideo: false,
      fromName: 'Notify Caller',
      fromUid: callerUid,
      callkitId: exactId(inviteId),
    );
  }

  Future<void> finishCall(WidgetTester tester, String inviteId) async {
    await pumped(
      tester,
      manager.endCallFromLocalUser(inviteId: inviteId, source: 'end_button'),
    );
    await pumped(tester, manager.debugCloseHeldRouteForTest(inviteId));
    await pumped(
      tester,
      manager.hardResetForNewCall(
        reason: 'test_end_reset',
        expectedInviteId: inviteId,
        expectedCallkitId: exactId(inviteId),
      ),
    );
    await pumpFor(tester, const Duration(seconds: 1));
  }

  setUp(() async {
    firestore = _WedgeableFirestore();
    HelperlyTestRuntime.configureForTest(
      firestore: firestore,
      currentUid: calleeUid,
      currentDisplayName: 'Notify Callee',
    );
    manager = CallSessionManager.instance;
    await manager.clearForSignedOut();
    await manager.forceIdleForTest();
    manager.debugConfigureAcceptedNativeRouteWatchForTest(
      timeout: const Duration(seconds: 20),
    );
    HelperlyTestRuntime.configureForTest(
      firestore: firestore,
      currentUid: calleeUid,
      currentDisplayName: 'Notify Callee',
    );
  });

  tearDown(() async {
    await notifications.dispose();
    await manager.forceIdleForTest();
    await manager.clearForSignedOut();
    HelperlyTestRuntime.clear();
  });

  testWidgets(
      'wedged Firestore transactions: accept, stages, end, and the next call '
      'all complete through HTTPS signaling', (tester) async {
    await start(tester, withSignaling: true);
    await seedRinging('invite_b');
    await seedRinging('invite_c');
    firestore.transactionsWedged = true;

    unawaited(nativeAccept('invite_b'));
    await pumpFor(tester, const Duration(seconds: 3));
    expect(opened, <String>['invite_b']);
    expect(await status('invite_b'), CallInviteStatus.accepted.name);

    await pumped(
      tester,
      manager.reportMediaSetupBegan(inviteId: 'invite_b', isCaller: false),
    );
    expect(await status('invite_b'), CallInviteStatus.joining.name);
    await pumped(
      tester,
      manager.reportAgoraJoinSuccess(inviteId: 'invite_b', isCaller: false),
    );
    await pumped(
      tester,
      manager.reportRemoteJoined(inviteId: 'invite_b', isCaller: false),
    );
    expect(await status('invite_b'), CallInviteStatus.connected.name);

    await finishCall(tester, 'invite_b');
    expect(await status('invite_b'), CallInviteStatus.ended.name);
    expect(manager.isIdleForDebug, isTrue);

    unawaited(nativeAccept('invite_c'));
    await pumpFor(tester, const Duration(seconds: 3));
    expect(opened, <String>['invite_b', 'invite_c']);
    expect(await status('invite_c'), CallInviteStatus.accepted.name);
    expect(
        signaling.actions,
        containsAllInOrder(<String>[
          'accept',
          'stage',
          'stage',
          'terminal',
          'accept',
        ]));
    await manager.forceIdleForTest();
  }, timeout: const Timeout(Duration(minutes: 2)));

  testWidgets(
      'without HTTPS signaling a wedged terminal transaction is bounded and '
      'does not leave the lifecycle stuck in teardown', (tester) async {
    await start(tester, withSignaling: false);
    await seedRinging('invite_b');
    unawaited(nativeAccept('invite_b'));
    await pumpFor(tester, const Duration(seconds: 3));
    expect(opened, <String>['invite_b']);

    firestore.transactionsWedged = true;
    unawaited(manager.endCallFromLocalUser(
      inviteId: 'invite_b',
      source: 'end_button',
    ));
    await pumped(tester, manager.debugCloseHeldRouteForTest('invite_b'));
    await pumpFor(tester, const Duration(seconds: 12));
    await pumped(
      tester,
      manager.hardResetForNewCall(
        reason: 'test_end_reset',
        expectedInviteId: 'invite_b',
        expectedCallkitId: exactId('invite_b'),
      ),
    );
    await pumpFor(tester, const Duration(seconds: 1));

    expect(manager.isIdleForDebug, isTrue,
        reason: 'teardown must not await a wedged transaction forever');
    await manager.forceIdleForTest();
  }, timeout: const Timeout(Duration(minutes: 2)));

  testWidgets('HTTPS unavailable falls back to the Firestore transaction',
      (tester) async {
    await start(tester, withSignaling: true);
    signaling.available = false;
    await seedRinging('invite_b');

    unawaited(nativeAccept('invite_b'));
    await pumpFor(tester, const Duration(seconds: 3));

    expect(opened, <String>['invite_b']);
    expect(await status('invite_b'), CallInviteStatus.accepted.name);
    expect(signaling.actions, contains('accept'));
    expect(firestore.transactionsStarted, greaterThan(0));
    await manager.forceIdleForTest();
  }, timeout: const Timeout(Duration(minutes: 2)));
}
