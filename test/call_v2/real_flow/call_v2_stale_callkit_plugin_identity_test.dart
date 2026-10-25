import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:connect_app/services/call_session_manager.dart';
import 'package:connect_app/services/callkit_id.dart';
import 'package:connect_app/services/helperly_test_runtime.dart';
import 'package:connect_app/services/notification_service.dart';

/// Models the iOS facts the stale plugin identity defect depends on.
///
/// `flutter_callkit_incoming` 3.0.0 sends accept, decline, provider-timeout
/// and unknown-call end events with its process-wide `self.data`, which only
/// changes on `fromPushKit: true` presentations. AppDelegate records the exact
/// answered/ended call in its per-CallKit presentation ledger and stored
/// accepted identity inside the same main-queue provider callback, before
/// Flutter can query it.
class _FakeIosCallkit {
  final Map<String, String> ledger = <String, String>{};
  final Map<String, dynamic> stored = <String, dynamic>{};
  final List<String> endedNative = <String>[];
  Map<String, dynamic>? pluginSelfData;

  static String exactId(String inviteId) =>
      normalizeCallkitId(rawId: inviteId, fallback: 'channel_$inviteId');

  static Map<String, dynamic> callData(String inviteId,
      {bool isVideo = false}) {
    final id = exactId(inviteId);
    return <String, dynamic>{
      'id': id,
      'nameCaller': 'Notify Caller',
      'type': isVideo ? 1 : 0,
      'extra': <String, dynamic>{
        'id': id,
        'callkitId': id,
        'callId': inviteId,
        'inviteId': inviteId,
        'channel': 'channel_$inviteId',
        'fromUid': 'notify_caller',
        'fromName': 'Notify Caller',
        'isVideo': isVideo ? 'true' : 'false',
      },
    };
  }

  void present(String inviteId,
      {required bool fromPushKit, bool isVideo = false}) {
    ledger[exactId(inviteId)] = 'presented';
    if (fromPushKit) pluginSelfData = callData(inviteId, isVideo: isVideo);
  }

  void recordEvent(String kind, String inviteId) {
    stored['lastCallkitEvent'] = kind;
    stored['lastCallkitEventAt'] = DateTime.now().toUtc().toIso8601String();
    stored['lastCallkitEventInviteId'] = inviteId;
    stored['lastCallkitEventCallkitId'] = exactId(inviteId);
    stored['lastCallkitEventChannel'] = 'channel_$inviteId';
  }

  void accept(String inviteId, {bool isVideo = false}) {
    ledger[exactId(inviteId)] = 'accepted';
    stored['lastCallkitAcceptedAt'] = DateTime.now().toUtc().toIso8601String();
    stored['lastCallkitAcceptedInviteId'] = inviteId;
    stored['lastCallkitAcceptedChannel'] = 'channel_$inviteId';
    stored['lastCallkitAcceptedCallkitId'] = exactId(inviteId);
    stored['lastCallkitAcceptedFromName'] = 'Notify Caller';
    stored['lastCallkitAcceptedFromUid'] = 'notify_caller';
    stored['lastCallkitAcceptedIsVideo'] = isVideo ? 'true' : 'false';
    recordEvent('accept', inviteId);
  }

  void terminal(String kind, String inviteId) {
    ledger[exactId(inviteId)] = 'terminal';
    prunedLedgerEntries.remove(exactId(inviteId));
    if (stored['lastCallkitAcceptedCallkitId'] == exactId(inviteId)) {
      for (final key in stored.keys.toList()) {
        if (key.startsWith('lastCallkitAccepted')) stored.remove(key);
      }
    }
    recordEvent(kind, inviteId);
  }

  /// Audio-session callbacks overwrite the single last-event slot natively.
  void audioSessionChanged(bool active) {
    stored['lastCallkitEvent'] =
        active ? 'audio_activated' : 'audio_deactivated';
    stored['lastCallkitEventInviteId'] = '';
    stored['lastCallkitEventCallkitId'] = '';
    stored['lastCallkitEventChannel'] = '';
  }

  final Set<String> prunedLedgerEntries = <String>{};

  /// The native ledger expires entries after 120 seconds; the system call
  /// observer keeps reporting a live call regardless.
  void pruneLedger(String inviteId) =>
      prunedLedgerEntries.add(exactId(inviteId));

  bool systemCallActive(String exactCallkitId) {
    final state = ledger[exactCallkitId];
    return state == 'presented' || state == 'accepted' || state == 'active';
  }

  Future<Map<String, dynamic>?> identityState(String callkitId) async {
    final key = callkitId.trim().toLowerCase();
    return <String, dynamic>{
      'state': prunedLedgerEntries.contains(key) ? '' : ledger[key] ?? '',
      'systemCallActive': systemCallActive(key),
    };
  }

  Future<Map<String, dynamic>?> tokens() async =>
      Map<String, dynamic>.from(stored);

  List<NativeCallSnapshot> liveCalls() => <NativeCallSnapshot>[
        for (final entry in ledger.entries)
          if (entry.value != 'terminal')
            NativeCallSnapshot(
              callkitId: entry.key,
              inviteId: '',
              channel: '',
              accepted: entry.value == 'accepted' || entry.value == 'active',
            ),
      ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const callerUid = 'notify_caller';
  const calleeUid = 'notify_callee';
  const calleeName = 'Notify Callee';

  late FakeFirebaseFirestore firestore;
  late CallSessionManager manager;
  late NotificationService notifications;
  late _FakeIosCallkit ios;
  late List<String> opened;
  late GlobalKey<NavigatorState> navigatorKey;

  String exactId(String inviteId) => _FakeIosCallkit.exactId(inviteId);

  Future<void> seedInvite(
    String inviteId,
    CallInviteStatus status, {
    bool isVideo = false,
  }) async {
    await firestore.collection('callInvites').doc(inviteId).set({
      'fromUid': callerUid,
      'fromName': 'Notify Caller',
      'toUid': calleeUid,
      'toName': calleeName,
      'channel': 'channel_$inviteId',
      'isVideo': isVideo,
      'status': status.name,
      'createdAt': Timestamp.now(),
    });
  }

  Future<String?> status(String inviteId) async =>
      (await firestore.collection('callInvites').doc(inviteId).get())
          .data()?['status'] as String?;

  CallScreenOpenRecorderForTest recorder(List<String> routes) {
    return ({
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
      routes.add(isVideo ? '$inviteId:video' : inviteId);
    };
  }

  Future<void> startHarness(
    WidgetTester tester, {
    bool nativeIdentityAvailable = true,
  }) async {
    navigatorKey = GlobalKey<NavigatorState>();
    opened = <String>[];
    ios = _FakeIosCallkit();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigatorKey,
      home: const Scaffold(body: Text('home')),
    ));
    notifications = NotificationService(
      iosCallkitPlatformForTest: true,
      nativeCallkitIdentityStateForTest:
          nativeIdentityAvailable ? ios.identityState : null,
      nativeStoredPushTokensForTest:
          nativeIdentityAvailable ? ios.tokens : null,
    );
    notifications.debugBeginPushBindingForTest(calleeUid);
    manager.configure(
      navigatorKey: navigatorKey,
      listNativeCalls: () async => ios.liveCalls(),
      endNativeCall: (id) async => ios.endedNative.add(id),
      appForegroundProvider: () async => true,
      callScreenOpenRecorderForTest: recorder(opened),
      skipActiveInviteBindingForTest: true,
      iosCallkitOnlyIncomingUiForTest: true,
    );
  }

  Future<void> pumpFor(WidgetTester tester, Duration duration) async {
    final steps = duration.inMilliseconds ~/ 100;
    for (var i = 0; i < steps; i += 1) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> nativeBridge(String inviteId, {bool isVideo = false}) {
    return notifications.debugSimulateNativeAcceptedCallkitBridgeForTest(
      inviteId: inviteId,
      channel: 'channel_$inviteId',
      isVideo: isVideo,
      fromName: 'Notify Caller',
      fromUid: callerUid,
      callkitId: exactId(inviteId),
    );
  }

  /// Delivers exactly what the plugin sends: `self.data` for accept.
  Future<void> pluginAccept() {
    return notifications.debugSimulateCallkitPluginEventForTest(
      Event.actionCallAccept,
      Map<String, dynamic>.from(ios.pluginSelfData!)..['isAccepted'] = true,
    );
  }

  Future<void> pluginDecline() {
    return notifications.debugSimulateCallkitPluginEventForTest(
      Event.actionCallDecline,
      Map<String, dynamic>.from(ios.pluginSelfData!),
    );
  }

  Future<void> pluginEnded(Map<String, dynamic> body) {
    return notifications.debugSimulateCallkitPluginEventForTest(
      Event.actionCallEnded,
      body,
    );
  }

  Future<void> pluginTimeout(Map<String, dynamic> body) {
    return notifications.debugSimulateCallkitPluginEventForTest(
      Event.actionCallTimeout,
      body,
    );
  }

  /// Call A presented by PushKit (plugin `self.data` = A), then declined.
  Future<void> declinedCallA(String inviteId) async {
    await seedInvite(inviteId, CallInviteStatus.declined);
    ios.present(inviteId, fromPushKit: true);
    ios.terminal('decline', inviteId);
  }

  /// Plugin answer handler: sendEvent(self.data) then AppDelegate.onAccept,
  /// which records exact native state and dispatches the exact bridge.
  Future<void> acceptWithPluginFirst(String inviteId,
      {bool isVideo = false}) async {
    ios.accept(inviteId, isVideo: isVideo);
    unawaited(pluginAccept());
    unawaited(nativeBridge(inviteId, isVideo: isVideo));
  }

  void expectOnlyRoute(String route) {
    expect(opened, <String>[route]);
    expect(manager.debugSnapshot()['routeOpenCount'], 1);
    expect(manager.debugSnapshot()['rtcSetupOwnerCount'], 1);
  }

  void expectNoRecoveryRetry() {
    final snapshot = notifications.debugSnapshotForTest();
    expect(snapshot['acceptedRecoveryRetryScheduled'], isFalse);
    expect(snapshot['acceptedRecoveryRetryAttempts'], 0);
  }

  Future<void> endAndReset(WidgetTester tester, String inviteId) async {
    await manager.endCallFromLocalUser(inviteId: inviteId, source: 'test_end');
    ios.terminal('end', inviteId);
    // The recorder stands in for the pushed call route; closing it completes
    // route ownership exactly as the popped production route does.
    await manager.debugCloseHeldRouteForTest(inviteId);
    await manager.hardResetForNewCall(
      reason: 'test_end_reset',
      expectedInviteId: inviteId,
      expectedCallkitId: exactId(inviteId),
    );
    await pumpFor(tester, const Duration(milliseconds: 500));
  }

  void harnessTest(
    String description,
    Future<void> Function(WidgetTester tester) body,
  ) {
    testWidgets(description, (tester) async {
      await body(tester);
      await manager.forceIdleForTest();
      await notifications.dispose();
    });
  }

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    HelperlyTestRuntime.configureForTest(
      firestore: firestore,
      currentUid: calleeUid,
      currentDisplayName: calleeName,
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
      currentDisplayName: calleeName,
    );
  });

  tearDown(() async {
    await notifications.dispose();
    await manager.forceIdleForTest();
    await manager.clearForSignedOut();
    HelperlyTestRuntime.clear();
  });

  group('manager isolation without native identity validation', () {
    // Uses only hooks that exist on the unchanged baseline: the stale plugin
    // accept path is driven directly, so this proves the manager alone never
    // lets declined Call A's terminal observation suppress accepted Call B.
    harnessTest('A declined then B accepted with stale plugin identity first',
        (tester) async {
      await startHarness(tester, nativeIdentityAvailable: false);
      await seedInvite('invite_a', CallInviteStatus.declined);
      await seedInvite('invite_b', CallInviteStatus.ringing);
      ios.accept('invite_b');

      unawaited(notifications.debugSimulateAcceptedCallkitEventForTest(
        inviteId: 'invite_a',
        channel: 'channel_invite_a',
        isVideo: false,
        fromName: 'Notify Caller',
        fromUid: callerUid,
      ));
      unawaited(nativeBridge('invite_b'));
      await pumpFor(tester, const Duration(seconds: 3));

      expectOnlyRoute('invite_b');
      expect(await status('invite_a'), CallInviteStatus.declined.name);
      expect(await status('invite_b'), isNot(CallInviteStatus.ringing.name));
      expect(await status('invite_b'), isNot(CallInviteStatus.failed.name));
      expect(manager.activeInviteId, 'invite_b');

      await pumpFor(tester, const Duration(seconds: 22));
      expect(await status('invite_b'), isNot(CallInviteStatus.failed.name));
      expect(ios.endedNative, isNot(contains(exactId('invite_b'))));
      expect(manager.activeInviteId, 'invite_b');
    });
  });

  group('exact native identity validation of plugin events', () {
    harnessTest('A declined then B accepted, stale plugin event first',
        (tester) async {
      await startHarness(tester);
      await declinedCallA('invite_a');
      await seedInvite('invite_b', CallInviteStatus.ringing);
      ios.present('invite_b', fromPushKit: false);

      await acceptWithPluginFirst('invite_b');
      await pumpFor(tester, const Duration(seconds: 3));

      expectOnlyRoute('invite_b');
      expectNoRecoveryRetry();
      expect(await status('invite_a'), CallInviteStatus.declined.name);
      expect(await status('invite_b'), CallInviteStatus.accepted.name);
      expect(ios.endedNative, isNot(contains(exactId('invite_b'))));
    });

    harnessTest('A declined then B accepted, native bridge first',
        (tester) async {
      await startHarness(tester);
      await declinedCallA('invite_a');
      await seedInvite('invite_b', CallInviteStatus.ringing);
      ios.present('invite_b', fromPushKit: false);

      ios.accept('invite_b');
      await nativeBridge('invite_b');
      await pumpFor(tester, const Duration(milliseconds: 500));
      await pluginAccept();
      await pumpFor(tester, const Duration(seconds: 3));

      expectOnlyRoute('invite_b');
      expectNoRecoveryRetry();
      expect(manager.debugSnapshot()['busyInviteDeclinedCount'], 0);
      expect(await status('invite_a'), CallInviteStatus.declined.name);
      expect(await status('invite_b'), CallInviteStatus.accepted.name);
      expect(ios.endedNative, isNot(contains(exactId('invite_b'))));
    });

    for (final nativeFirst in <bool>[true, false]) {
      harnessTest(
          'valid plugin and native duplicate accept for the same call '
          '(nativeFirst=$nativeFirst)', (tester) async {
        await startHarness(tester);
        await seedInvite('invite_b', CallInviteStatus.ringing);
        ios.present('invite_b', fromPushKit: true);
        ios.accept('invite_b');

        if (nativeFirst) {
          await nativeBridge('invite_b');
          await pumpFor(tester, const Duration(milliseconds: 500));
          await pluginAccept();
        } else {
          unawaited(pluginAccept());
          unawaited(nativeBridge('invite_b'));
        }
        await pumpFor(tester, const Duration(seconds: 3));

        expectOnlyRoute('invite_b');
        expectNoRecoveryRetry();
        expect(await status('invite_b'), CallInviteStatus.accepted.name);
      });
    }

    harnessTest('plugin accept alone still opens a legitimate call',
        (tester) async {
      await startHarness(tester);
      await seedInvite('invite_b', CallInviteStatus.ringing);
      ios.present('invite_b', fromPushKit: true);
      ios.accept('invite_b');

      await pluginAccept();
      await pumpFor(tester, const Duration(seconds: 3));

      expectOnlyRoute('invite_b');
      expect(await status('invite_b'), CallInviteStatus.accepted.name);
    });

    harnessTest(
        'stale plugin accept is re-attributed to the exact native call when '
        'the native bridge never arrives', (tester) async {
      await startHarness(tester);
      await declinedCallA('invite_a');
      await seedInvite('invite_b', CallInviteStatus.ringing);
      ios.present('invite_b', fromPushKit: false);
      ios.accept('invite_b');

      await pluginAccept();
      await pumpFor(tester, const Duration(seconds: 3));

      expectOnlyRoute('invite_b');
      expect(await status('invite_a'), CallInviteStatus.declined.name);
      expect(await status('invite_b'), CallInviteStatus.accepted.name);
    });

    harnessTest('delayed A terminal callbacks after B connects leave B intact',
        (tester) async {
      await startHarness(tester);
      await declinedCallA('invite_a');
      await seedInvite('invite_b', CallInviteStatus.ringing);
      ios.present('invite_b', fromPushKit: false);
      await acceptWithPluginFirst('invite_b');
      await pumpFor(tester, const Duration(seconds: 2));
      expectOnlyRoute('invite_b');
      ios.audioSessionChanged(true);

      // Late plugin end for A's unknown UUID carries the plugin's self.data (A).
      await pluginEnded(_FakeIosCallkit.callData('invite_a'));
      await pluginTimeout(_FakeIosCallkit.callData('invite_a'));
      await notifications.debugSimulateNativeSafetyTerminatedForTest(
        callkitId: exactId('invite_a'),
      );
      await pumpFor(tester, const Duration(seconds: 2));

      expect(manager.activeInviteId, 'invite_b');
      expect(manager.terminalSignal.value, isNull);
      expect(await status('invite_b'), CallInviteStatus.accepted.name);
      expect(ios.endedNative, isNot(contains(exactId('invite_b'))));
      expect(opened, <String>['invite_b']);
    });

    harnessTest('B declined while foregrounded declines exact B, not stale A',
        (tester) async {
      await startHarness(tester);
      await declinedCallA('invite_a');
      await seedInvite('invite_b', CallInviteStatus.ringing);
      ios.present('invite_b', fromPushKit: false);

      ios.terminal('decline', 'invite_b');
      await pluginDecline();
      await pumpFor(tester, const Duration(seconds: 1));

      expect(await status('invite_b'), CallInviteStatus.declined.name);
      expect(await status('invite_a'), CallInviteStatus.declined.name);
      expect(opened, isEmpty);
    });

    harnessTest('stale plugin decline for a live call is rejected',
        (tester) async {
      await startHarness(tester);
      await seedInvite('invite_b', CallInviteStatus.ringing);
      ios.present('invite_b', fromPushKit: true);
      // Native last event is unrelated, so the plugin decline (self.data = B)
      // has no exact native corroboration while B is still presented.
      ios.audioSessionChanged(false);

      await pluginDecline();
      await pumpFor(tester, const Duration(seconds: 1));

      expect(await status('invite_b'), CallInviteStatus.ringing.name);
    });

    harnessTest('B ended natively while A has stale plugin state ends B',
        (tester) async {
      await startHarness(tester);
      await declinedCallA('invite_a');
      await seedInvite('invite_b', CallInviteStatus.ringing);
      ios.present('invite_b', fromPushKit: false);
      await acceptWithPluginFirst('invite_b');
      await pumpFor(tester, const Duration(seconds: 2));
      expectOnlyRoute('invite_b');
      ios.audioSessionChanged(true);

      // Found-call end: the plugin sends B's exact call.data.
      ios.terminal('end', 'invite_b');
      ios.audioSessionChanged(false);
      await pluginEnded(_FakeIosCallkit.callData('invite_b'));
      await pumpFor(tester, const Duration(seconds: 1));

      expect(await status('invite_b'), CallInviteStatus.ended.name);
      expect(await status('invite_a'), CallInviteStatus.declined.name);
      expect(manager.terminalSignal.value?.inviteId, 'invite_b');
    });

    harnessTest(
        'stale plugin end or timeout carrying live B identity is ignored',
        (tester) async {
      await startHarness(tester);
      await declinedCallA('invite_a');
      await seedInvite('invite_b', CallInviteStatus.ringing);
      ios.present('invite_b', fromPushKit: true);
      await acceptWithPluginFirst('invite_b');
      await pumpFor(tester, const Duration(seconds: 2));
      expectOnlyRoute('invite_b');
      ios.audioSessionChanged(true);

      // Flutter-side cleanup ends A's unknown UUID; the plugin reports
      // self.data (now B) although native B is still accepted.
      await pluginEnded(Map<String, dynamic>.from(ios.pluginSelfData!));
      await pluginTimeout(Map<String, dynamic>.from(ios.pluginSelfData!));
      await pumpFor(tester, const Duration(seconds: 1));

      expect(manager.activeInviteId, 'invite_b');
      expect(manager.terminalSignal.value, isNull);
      expect(await status('invite_b'), CallInviteStatus.accepted.name);
    });

    harnessTest(
        'stale plugin end for a long live call is ignored after ledger expiry',
        (tester) async {
      await startHarness(tester);
      await declinedCallA('invite_a');
      await seedInvite('invite_b', CallInviteStatus.ringing);
      ios.present('invite_b', fromPushKit: true);
      // Exact native bridge only, so the legacy recent-accept filter (which
      // the plugin accept arms) cannot mask the stale end.
      ios.accept('invite_b');
      await nativeBridge('invite_b');
      await pumpFor(tester, const Duration(seconds: 25));
      expectOnlyRoute('invite_b');
      ios.pruneLedger('invite_b');

      await pluginEnded(Map<String, dynamic>.from(ios.pluginSelfData!));
      await pumpFor(tester, const Duration(seconds: 1));

      expect(manager.activeInviteId, 'invite_b');
      expect(manager.terminalSignal.value, isNull);
      expect(await status('invite_b'), CallInviteStatus.accepted.name);
    });

    harnessTest('B stays connected past the native watch deadline',
        (tester) async {
      await startHarness(tester);
      await declinedCallA('invite_a');
      await seedInvite('invite_b', CallInviteStatus.ringing);
      ios.present('invite_b', fromPushKit: false);
      await acceptWithPluginFirst('invite_b');
      await pumpFor(tester, const Duration(seconds: 25));

      expectOnlyRoute('invite_b');
      expect(manager.activeInviteId, 'invite_b');
      expect(manager.debugSnapshot()['acceptedNativeWatchDeadlineReached'],
          isFalse);
      expect(await status('invite_b'), CallInviteStatus.accepted.name);
      expect(ios.endedNative, isNot(contains(exactId('invite_b'))));
    });

    harnessTest('repeated stale-identity calls leak no recovery retry timers',
        (tester) async {
      await startHarness(tester);
      await declinedCallA('invite_0');
      for (var i = 1; i <= 3; i += 1) {
        final inviteId = 'invite_$i';
        await seedInvite(inviteId, CallInviteStatus.ringing);
        ios.present(inviteId, fromPushKit: false);
        await acceptWithPluginFirst(inviteId);
        await pumpFor(tester, const Duration(seconds: 2));

        expect(opened.isEmpty ? null : opened.last, inviteId);
        expect(manager.activeInviteId, inviteId);
        expectNoRecoveryRetry();

        await endAndReset(tester, inviteId);
        expectNoRecoveryRetry();
        expect(manager.isIdleForDebug, isTrue, reason: 'after $inviteId');
        expect(
          manager.debugResourceCounts()['acceptedNativeWatchListenerCount'] ??
              0,
          0,
        );
      }
      expect(opened, <String>['invite_1', 'invite_2', 'invite_3']);
    });

    harnessTest('Audio A -> Audio B -> Video C keep exact lifecycle isolation',
        (tester) async {
      await startHarness(tester);
      // Audio A arrives by PushKit, connects, and ends.
      await seedInvite('invite_audio_a', CallInviteStatus.ringing);
      ios.present('invite_audio_a', fromPushKit: true);
      await acceptWithPluginFirst('invite_audio_a');
      await pumpFor(tester, const Duration(seconds: 2));
      expect(opened, <String>['invite_audio_a']);
      await endAndReset(tester, 'invite_audio_a');

      // Audio B is presented from Flutter: the plugin still holds A.
      await seedInvite('invite_audio_b', CallInviteStatus.ringing);
      ios.present('invite_audio_b', fromPushKit: false);
      await acceptWithPluginFirst('invite_audio_b');
      await pumpFor(tester, const Duration(seconds: 2));
      expect(opened.isEmpty ? null : opened.last, 'invite_audio_b');
      await endAndReset(tester, 'invite_audio_b');

      // Video C is presented from Flutter too; plugin self.data is still A.
      await seedInvite('invite_video_c', CallInviteStatus.ringing,
          isVideo: true);
      ios.present('invite_video_c', fromPushKit: false, isVideo: true);
      await acceptWithPluginFirst('invite_video_c', isVideo: true);
      await pumpFor(tester, const Duration(seconds: 2));

      // Late terminal callbacks for A and B must not touch C.
      await pluginEnded(_FakeIosCallkit.callData('invite_audio_a'));
      await pluginEnded(_FakeIosCallkit.callData('invite_audio_b'));
      await notifications.debugSimulateNativeSafetyTerminatedForTest(
        callkitId: exactId('invite_audio_b'),
      );
      await pumpFor(tester, const Duration(seconds: 22));

      expect(opened, <String>[
        'invite_audio_a',
        'invite_audio_b',
        'invite_video_c:video',
      ]);
      expect(manager.activeInviteId, 'invite_video_c');
      expect(manager.terminalSignal.value, isNull);
      expect(await status('invite_video_c'), CallInviteStatus.accepted.name);
      expect(ios.endedNative, isNot(contains(exactId('invite_video_c'))));
      expectNoRecoveryRetry();
    });
  });
}
