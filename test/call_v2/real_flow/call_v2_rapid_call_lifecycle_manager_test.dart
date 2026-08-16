import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:connect_app/call_v2/real_flow/call_v2_call_lifecycle_arbiter.dart';
import 'package:connect_app/services/call_session_manager.dart';
import 'package:connect_app/services/helperly_test_runtime.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const callerUid = 'rapid_caller';
  const calleeUid = 'rapid_callee';
  const callerName = 'Rapid Caller';
  const calleeName = 'Rapid Callee';

  late FakeFirebaseFirestore firestore;
  late GlobalKey<NavigatorState> navigatorKey;
  late CallSessionManager manager;

  Widget buildHarness() {
    return MaterialApp(
      navigatorKey: navigatorKey,
      home: const Scaffold(body: Text('home')),
    );
  }

  Future<void> seedInvite(
    String inviteId, {
    CallInviteStatus status = CallInviteStatus.ringing,
  }) async {
    await firestore.collection('callInvites').doc(inviteId).set({
      'fromUid': callerUid,
      'fromName': callerName,
      'toUid': calleeUid,
      'toName': calleeName,
      'channel': 'channel_$inviteId',
      'isVideo': false,
      'status': status.name,
      'createdAt': Timestamp.now(),
      'callerStage': status.name,
      'calleeStage': status.name,
    });
  }

  NativeCallSnapshot nativeForInvite(String inviteId) {
    return NativeCallSnapshot(
      callkitId: 'native_$inviteId',
      inviteId: inviteId,
      channel: 'channel_$inviteId',
    );
  }

  void configureIosCallkitOnly({
    required List<NativeCallSnapshot> nativeCalls,
    List<String>? presentedInvites,
    List<String>? markedStates,
    CallScreenOpenRecorderForTest? routeRecorder,
    NativeIncomingCallPresenter? presenter,
  }) {
    manager.configure(
      navigatorKey: navigatorKey,
      appForegroundProvider: () async => true,
      listNativeCalls: () async => List<NativeCallSnapshot>.from(nativeCalls),
      endNativeCall: (callkitId) async {
        nativeCalls.removeWhere((call) => call.callkitId == callkitId);
      },
      presentNativeIncomingCall: presenter ??
          (payload) async {
            presentedInvites?.add(payload.inviteId);
            nativeCalls.add(nativeForInvite(payload.inviteId));
            return true;
          },
      markNativeInviteState: ({
        required String inviteId,
        required String channel,
        required String state,
      }) async {
        markedStates?.add(state);
      },
      iosCallkitOnlyIncomingUiForTest: true,
      callScreenOpenRecorderForTest: routeRecorder,
      skipActiveInviteBindingForTest: routeRecorder != null,
    );
  }

  Future<void> claimCallkitOwnedInvite(
    WidgetTester tester,
    String inviteId,
    List<NativeCallSnapshot> nativeCalls,
  ) async {
    await seedInvite(inviteId);
    manager.configure(
      navigatorKey: navigatorKey,
      appForegroundProvider: () async => true,
      listNativeCalls: () async => List<NativeCallSnapshot>.from(nativeCalls),
      endNativeCall: (callkitId) async {
        nativeCalls.removeWhere((call) => call.callkitId == callkitId);
      },
    );
    await manager.handleNotificationInviteTap(
      inviteId: inviteId,
      channel: 'channel_$inviteId',
      isVideo: false,
      fromName: callerName,
      fromUid: callerUid,
      source: 'callkit_owned_test',
    );
    await tester.pump(const Duration(milliseconds: 350));
    expect(manager.debugSnapshot()['incomingUiOwner'], 'callkit');
    expect(manager.debugSnapshot()['activePromptCount'], 1);
  }

  Future<void> expectIdleAfterCallkitTerminal(
    WidgetTester tester,
    String nextInviteId,
    List<NativeCallSnapshot> nativeCalls,
  ) async {
    final snapshot = manager.debugSnapshot();
    expect(snapshot['sessionIdle'], isTrue);
    expect(snapshot['incomingUiOwner'], IncomingUiOwner.none.name);
    expect(snapshot['activePromptCount'], 0);
    expect(snapshot['activeCallRouteCount'], 0);
    expect(nativeCalls, isEmpty);

    nativeCalls.add(nativeForInvite(nextInviteId));
    await seedInvite(nextInviteId);
    await manager.handleNotificationInviteTap(
      inviteId: nextInviteId,
      channel: 'channel_$nextInviteId',
      isVideo: false,
      fromName: callerName,
      fromUid: callerUid,
      source: 'next_after_terminal',
    );
    for (var i = 0; i < 20; i += 1) {
      await tester.pump(const Duration(milliseconds: 100));
      if (manager.debugSnapshot()['incomingUiOwner'] ==
          IncomingUiOwner.callkit.name) {
        break;
      }
    }
    final nextSnapshot = manager.debugSnapshot();
    expect(nextSnapshot['incomingUiOwner'], IncomingUiOwner.callkit.name);
    expect(nextSnapshot['activePromptCount'], 1);
  }

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    navigatorKey = GlobalKey<NavigatorState>();
    manager = CallSessionManager.instance;
    HelperlyTestRuntime.configureForTest(
      firestore: firestore,
      currentUid: calleeUid,
      currentDisplayName: calleeName,
    );
    await manager.clearForSignedOut();
    await manager.forceIdleForTest();
    HelperlyTestRuntime.configureForTest(
      firestore: firestore,
      currentUid: calleeUid,
      currentDisplayName: calleeName,
    );
    manager.configure(
      navigatorKey: navigatorKey,
      listNativeCalls: () async => const <NativeCallSnapshot>[],
      appForegroundProvider: () async => true,
    );
  });

  tearDown(() async {
    await manager.clearForSignedOut();
    HelperlyTestRuntime.clear();
  });

  testWidgets('notification during terminal route teardown stays pending',
      (tester) async {
    await tester.pumpWidget(buildHarness());
    await seedInvite('invite_b');
    await manager.debugCreateHeldCallRouteForTest(
      inviteId: 'invite_a',
      channel: 'channel_a',
    );
    await manager.debugMarkHeldRouteTerminalForTest('invite_a');

    await manager.handleNotificationInviteTap(
      inviteId: 'invite_b',
      channel: 'channel_b',
      isVideo: false,
      fromName: callerName,
      fromUid: callerUid,
      source: 'notification_test',
    );
    await manager.debugRunPreflightForTest('notification_terminal_teardown');
    await tester.pump(const Duration(milliseconds: 100));

    final snapshot = manager.debugSnapshot();
    expect(snapshot['callLifecycleState'], 'teardown');
    expect(snapshot['pendingIncomingPresent'], isTrue);
    expect(snapshot['pendingIncomingCount'], 1);
    expect(snapshot['activePromptCount'], 0);
    expect(find.text('Incoming Audio Call'), findsNothing);
    await manager.clearForSignedOut();
    await tester.pump();
  });

  testWidgets('CallKit recovery during terminal route teardown stays pending',
      (tester) async {
    await tester.pumpWidget(buildHarness());
    await seedInvite('invite_b');
    await manager.debugCreateHeldCallRouteForTest(
      inviteId: 'invite_a',
      channel: 'channel_a',
    );
    await manager.debugMarkHeldRouteTerminalForTest('invite_a');

    await manager.handleRecoveredAcceptedInvite(
      inviteId: 'invite_b',
      channel: 'channel_b',
      isVideo: false,
      fromName: callerName,
      fromUid: callerUid,
    );
    await manager.debugRunPreflightForTest('callkit_terminal_teardown');
    await tester.pump(const Duration(milliseconds: 100));

    final snapshot = manager.debugSnapshot();
    expect(snapshot['callLifecycleState'], 'teardown');
    expect(snapshot['pendingIncomingPresent'], isTrue);
    expect(snapshot['activePromptCount'], 0);
    expect(find.text('Incoming Audio Call'), findsNothing);
    await manager.clearForSignedOut();
    await tester.pump();
  });

  testWidgets('newer pending invite supersedes older and owns after teardown',
      (tester) async {
    await tester.pumpWidget(buildHarness());
    await seedInvite('invite_b');
    await seedInvite('invite_c');
    await manager.debugCreateHeldCallRouteForTest(
      inviteId: 'invite_a',
      channel: 'channel_a',
    );
    await manager.debugMarkHeldRouteTerminalForTest('invite_a');
    await manager.debugRunPreflightForTest('held_route_teardown');

    await manager.handleNotificationInviteTap(
      inviteId: 'invite_b',
      channel: 'channel_b',
      isVideo: false,
      fromName: callerName,
      fromUid: callerUid,
      source: 'pending_b',
    );
    await manager.handleNotificationInviteTap(
      inviteId: 'invite_c',
      channel: 'channel_c',
      isVideo: false,
      fromName: callerName,
      fromUid: callerUid,
      source: 'pending_c',
    );

    final inviteB =
        await firestore.collection('callInvites').doc('invite_b').get();
    expect(inviteB.data()?['status'], CallInviteStatus.declined.name);
    expect(manager.debugSnapshot()['pendingIncomingCount'], 1);
    expect(
      manager.debugSnapshot()['displacedPendingSupersededCount'],
      1,
    );

    final closeFuture = manager.debugCloseHeldRouteForTest('invite_a');
    for (var i = 0; i < 20; i += 1) {
      await tester.pump(const Duration(milliseconds: 100));
      if (manager.debugSnapshot()['callLifecycleState'] == 'incomingPrompt') {
        break;
      }
    }
    await manager.handleNotificationInviteTap(
      inviteId: 'invite_b',
      channel: 'channel_b',
      isVideo: false,
      fromName: callerName,
      fromUid: callerUid,
      source: 'old_b_between_handoff',
    );
    for (var attempt = 0;
        attempt < 20 && find.text('Incoming Audio Call').evaluate().isEmpty;
        attempt += 1) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('Incoming Audio Call'), findsOneWidget);
    expect(manager.debugSnapshot()['callLifecycleState'], 'incomingPrompt');
    expect(manager.debugSnapshot()['activePromptCount'], 1);

    navigatorKey.currentState!.pop(false);
    await tester.pump();
    await closeFuture.timeout(const Duration(seconds: 5));
    expect(manager.debugSnapshot()['pendingIncomingCount'], 0);
  });

  testWidgets('matching native CallKit call owns foreground incoming UI',
      (tester) async {
    await tester.pumpWidget(buildHarness());
    await seedInvite('invite_callkit');
    manager.configure(
      navigatorKey: navigatorKey,
      appForegroundProvider: () async => true,
      listNativeCalls: () async => const <NativeCallSnapshot>[
        NativeCallSnapshot(
          callkitId: '696e7669-7465-4c61-ac6c-6b6974696e76',
          inviteId: 'invite_callkit',
          channel: 'channel_invite_callkit',
        ),
      ],
    );

    await manager.handleNotificationInviteTap(
      inviteId: 'invite_callkit',
      channel: 'channel_invite_callkit',
      isVideo: false,
      fromName: callerName,
      fromUid: callerUid,
      source: 'foreground_test',
    );
    await tester.pump(const Duration(milliseconds: 350));

    final snapshot = manager.debugSnapshot();
    expect(snapshot['incomingUiOwner'], IncomingUiOwner.callkit.name);
    expect(snapshot['activePromptCount'], 1);
    expect(find.text('Incoming Audio Call'), findsNothing);
  });

  testWidgets('Firestore first waits for delayed PushKit CallKit owner',
      (tester) async {
    await tester.pumpWidget(buildHarness());
    final nativeCalls = <NativeCallSnapshot>[];
    final presented = <String>[];
    configureIosCallkitOnly(
      nativeCalls: nativeCalls,
      presentedInvites: presented,
    );
    await seedInvite('invite_delayed_pushkit');

    final handling = manager.handleNotificationInviteTap(
      inviteId: 'invite_delayed_pushkit',
      channel: 'channel_invite_delayed_pushkit',
      isVideo: false,
      fromName: callerName,
      fromUid: callerUid,
      source: 'firestore_first',
    );
    await tester.pump(const Duration(milliseconds: 300));
    nativeCalls.add(nativeForInvite('invite_delayed_pushkit'));
    await tester.pump(const Duration(milliseconds: 700));
    await handling;

    final snapshot = manager.debugSnapshot();
    expect(snapshot['incomingUiOwner'], IncomingUiOwner.callkit.name);
    expect(snapshot['flutterIncomingPromptCount'], 0);
    expect(snapshot['callkitFallbackRequestedCount'], 0);
    expect(presented, isEmpty);
    expect(find.text('Incoming Audio Call'), findsNothing);
  });

  testWidgets(
      'Firestore first without PushKit requests native CallKit fallback',
      (tester) async {
    await tester.pumpWidget(buildHarness());
    final nativeCalls = <NativeCallSnapshot>[];
    final presented = <String>[];
    configureIosCallkitOnly(
      nativeCalls: nativeCalls,
      presentedInvites: presented,
    );
    await seedInvite('invite_no_pushkit');

    final handling = manager.handleNotificationInviteTap(
      inviteId: 'invite_no_pushkit',
      channel: 'channel_invite_no_pushkit',
      isVideo: false,
      fromName: callerName,
      fromUid: callerUid,
      source: 'firestore_first_no_pushkit',
    );
    await tester.pump(const Duration(seconds: 1));
    await handling;

    final snapshot = manager.debugSnapshot();
    expect(snapshot['incomingUiOwner'], IncomingUiOwner.callkit.name);
    expect(snapshot['flutterIncomingPromptCount'], 0);
    expect(snapshot['callkitFallbackRequestedCount'], 1);
    expect(snapshot['callkitPresentationCount'], 1);
    expect(presented, ['invite_no_pushkit']);
    expect(nativeCalls, hasLength(1));
    expect(find.text('Incoming Audio Call'), findsNothing);
  });

  testWidgets('PushKit first keeps one CallKit owner and no Flutter prompt',
      (tester) async {
    await tester.pumpWidget(buildHarness());
    final nativeCalls = <NativeCallSnapshot>[
      nativeForInvite('invite_push_first')
    ];
    final presented = <String>[];
    configureIosCallkitOnly(
      nativeCalls: nativeCalls,
      presentedInvites: presented,
    );
    await seedInvite('invite_push_first');

    await manager.handleNotificationInviteTap(
      inviteId: 'invite_push_first',
      channel: 'channel_invite_push_first',
      isVideo: false,
      fromName: callerName,
      fromUid: callerUid,
      source: 'pushkit_first',
    );
    await tester.pump();

    final snapshot = manager.debugSnapshot();
    expect(snapshot['incomingUiOwner'], IncomingUiOwner.callkit.name);
    expect(snapshot['flutterIncomingPromptCount'], 0);
    expect(snapshot['callkitFallbackRequestedCount'], 0);
    expect(presented, isEmpty);
  });

  testWidgets('Dart CallKit fallback then late PushKit stays single-owner',
      (tester) async {
    await tester.pumpWidget(buildHarness());
    final nativeCalls = <NativeCallSnapshot>[];
    final presented = <String>[];
    configureIosCallkitOnly(
      nativeCalls: nativeCalls,
      presentedInvites: presented,
    );
    await seedInvite('invite_late_pushkit');

    final first = manager.handleNotificationInviteTap(
      inviteId: 'invite_late_pushkit',
      channel: 'channel_invite_late_pushkit',
      isVideo: false,
      fromName: callerName,
      fromUid: callerUid,
      source: 'firestore_fallback',
    );
    await tester.pump(const Duration(seconds: 1));
    await first;
    await manager.handleNotificationInviteTap(
      inviteId: 'invite_late_pushkit',
      channel: 'channel_invite_late_pushkit',
      isVideo: false,
      fromName: callerName,
      fromUid: callerUid,
      source: 'late_pushkit',
    );

    final snapshot = manager.debugSnapshot();
    expect(snapshot['incomingUiOwner'], IncomingUiOwner.callkit.name);
    expect(snapshot['flutterIncomingPromptCount'], 0);
    expect(snapshot['callkitFallbackRequestedCount'], 1);
    expect(presented, ['invite_late_pushkit']);
    expect(nativeCalls, hasLength(1));
  });

  testWidgets('CallKit accept then late PushKit opens one route',
      (tester) async {
    await tester.pumpWidget(buildHarness());
    final nativeCalls = <NativeCallSnapshot>[
      nativeForInvite('invite_accept_late')
    ];
    final openedRoutes = <String>[];
    configureIosCallkitOnly(
      nativeCalls: nativeCalls,
      routeRecorder: ({
        required String inviteId,
        required String channel,
        required bool isVideo,
        required String otherUserName,
        required String? otherUserId,
        required bool isCaller,
        required connectionSystem,
        required bool callV2FallbackUsed,
        required String callV2BlockerCode,
      }) async {
        openedRoutes.add(inviteId);
      },
    );
    await seedInvite('invite_accept_late');

    await manager.handleNotificationInviteTap(
      inviteId: 'invite_accept_late',
      channel: 'channel_invite_accept_late',
      isVideo: false,
      fromName: callerName,
      fromUid: callerUid,
      source: 'firestore_first',
    );
    final accepted = await manager.handleRecoveredAcceptedInvite(
      inviteId: 'invite_accept_late',
      channel: 'channel_invite_accept_late',
      isVideo: false,
      fromName: callerName,
      fromUid: callerUid,
    );
    await manager.handleNotificationInviteTap(
      inviteId: 'invite_accept_late',
      channel: 'channel_invite_accept_late',
      isVideo: false,
      fromName: callerName,
      fromUid: callerUid,
      source: 'late_pushkit_after_accept',
    );

    final snapshot = manager.debugSnapshot();
    expect(accepted, AcceptedCallRecoveryResult.opened);
    expect(openedRoutes, ['invite_accept_late']);
    expect(snapshot['routeOpenCount'], 1);
    expect(snapshot['rtcSetupOwnerCount'], 1);
    expect(snapshot['flutterIncomingPromptCount'], 0);
    manager.forceIdleForTest();
  });

  testWidgets('terminal invite suppresses late PushKit resurrection',
      (tester) async {
    await tester.pumpWidget(buildHarness());
    final nativeCalls = <NativeCallSnapshot>[
      nativeForInvite('invite_terminal_late')
    ];
    final presented = <String>[];
    configureIosCallkitOnly(
      nativeCalls: nativeCalls,
      presentedInvites: presented,
    );
    await seedInvite('invite_terminal_late');

    await manager.handleNotificationInviteTap(
      inviteId: 'invite_terminal_late',
      channel: 'channel_invite_terminal_late',
      isVideo: false,
      fromName: callerName,
      fromUid: callerUid,
      source: 'firestore_first',
    );
    await manager.declineInvite(
      inviteId: 'invite_terminal_late',
      source: 'callkit_decline',
    );
    final latePush = manager.handleNotificationInviteTap(
      inviteId: 'invite_terminal_late',
      channel: 'channel_invite_terminal_late',
      isVideo: false,
      fromName: callerName,
      fromUid: callerUid,
      source: 'late_pushkit_after_terminal',
    );
    await tester.pump(const Duration(seconds: 1));
    await latePush;

    final snapshot = manager.debugSnapshot();
    expect(snapshot['sessionIdle'], isTrue);
    expect(snapshot['incomingUiOwner'], IncomingUiOwner.none.name);
    expect(snapshot['flutterIncomingPromptCount'], 0);
    expect(presented, isEmpty);
  });

  testWidgets('duplicate CallKit accept is idempotent', (tester) async {
    await tester.pumpWidget(buildHarness());
    final nativeCalls = <NativeCallSnapshot>[
      nativeForInvite('invite_double_accept')
    ];
    final openedRoutes = <String>[];
    configureIosCallkitOnly(
      nativeCalls: nativeCalls,
      routeRecorder: ({
        required String inviteId,
        required String channel,
        required bool isVideo,
        required String otherUserName,
        required String? otherUserId,
        required bool isCaller,
        required connectionSystem,
        required bool callV2FallbackUsed,
        required String callV2BlockerCode,
      }) async {
        openedRoutes.add(inviteId);
      },
    );
    await seedInvite('invite_double_accept');

    await manager.handleNotificationInviteTap(
      inviteId: 'invite_double_accept',
      channel: 'channel_invite_double_accept',
      isVideo: false,
      fromName: callerName,
      fromUid: callerUid,
      source: 'firestore_first',
    );
    final first = await manager.handleRecoveredAcceptedInvite(
      inviteId: 'invite_double_accept',
      channel: 'channel_invite_double_accept',
      isVideo: false,
      fromName: callerName,
      fromUid: callerUid,
    );
    final second = await manager.handleRecoveredAcceptedInvite(
      inviteId: 'invite_double_accept',
      channel: 'channel_invite_double_accept',
      isVideo: false,
      fromName: callerName,
      fromUid: callerUid,
    );

    final snapshot = manager.debugSnapshot();
    expect(first, AcceptedCallRecoveryResult.opened);
    expect(second, AcceptedCallRecoveryResult.alreadyOpen);
    expect(openedRoutes, ['invite_double_accept']);
    expect(snapshot['routeOpenCount'], 1);
    expect(snapshot['rtcSetupOwnerCount'], 1);
    manager.forceIdleForTest();
  });

  testWidgets('pending rapid next call uses CallKit fallback not Flutter',
      (tester) async {
    await tester.pumpWidget(buildHarness());
    final nativeCalls = <NativeCallSnapshot>[];
    final presented = <String>[];
    configureIosCallkitOnly(
      nativeCalls: nativeCalls,
      presentedInvites: presented,
    );
    await seedInvite('invite_b');
    await manager.debugCreateHeldCallRouteForTest(
      inviteId: 'invite_a',
      channel: 'channel_invite_a',
    );
    await manager.debugMarkHeldRouteTerminalForTest('invite_a');
    await manager.debugRunPreflightForTest('pending_rapid_preflight');

    await manager.handleNotificationInviteTap(
      inviteId: 'invite_b',
      channel: 'channel_invite_b',
      isVideo: false,
      fromName: callerName,
      fromUid: callerUid,
      source: 'pending_rapid_b',
    );
    expect(manager.debugSnapshot()['pendingIncomingPresent'], isTrue);
    final closeFuture = manager.debugCloseHeldRouteForTest('invite_a');
    await tester.pump(const Duration(seconds: 1));
    await closeFuture;
    await tester.pump(const Duration(seconds: 1));

    final snapshot = manager.debugSnapshot();
    expect(snapshot['incomingUiOwner'], IncomingUiOwner.callkit.name);
    expect(snapshot['flutterIncomingPromptCount'], 0);
    expect(snapshot['callkitFallbackRequestedCount'], 1);
    expect(presented, ['invite_b']);
    expect(find.text('Incoming Audio Call'), findsNothing);
  });

  testWidgets('CallKit-owned decline releases pre-session lifecycle',
      (tester) async {
    await tester.pumpWidget(buildHarness());
    final nativeCalls = <NativeCallSnapshot>[nativeForInvite('invite_decline')];
    await claimCallkitOwnedInvite(tester, 'invite_decline', nativeCalls);

    await manager.declineInvite(
      inviteId: 'invite_decline',
      source: 'callkit_decline',
    );
    await tester.pump();

    await expectIdleAfterCallkitTerminal(
        tester, 'invite_after_decline', nativeCalls);
  });

  testWidgets('CallKit-owned caller cancel snapshot releases lifecycle',
      (tester) async {
    await tester.pumpWidget(buildHarness());
    final nativeCalls = <NativeCallSnapshot>[nativeForInvite('invite_cancel')];
    await manager.bindIncomingInviteListener();
    await claimCallkitOwnedInvite(tester, 'invite_cancel', nativeCalls);

    await firestore.collection('callInvites').doc('invite_cancel').set({
      'status': CallInviteStatus.cancelled.name,
      'endedAt': Timestamp.now(),
    }, SetOptions(merge: true));
    for (var i = 0; i < 20; i += 1) {
      await tester.pump(const Duration(milliseconds: 100));
      if (manager.debugSnapshot()['sessionIdle'] == true) break;
    }

    await expectIdleAfterCallkitTerminal(
        tester, 'invite_after_cancel', nativeCalls);
  });

  testWidgets('CallKit-owned timeout releases pre-session lifecycle',
      (tester) async {
    await tester.pumpWidget(buildHarness());
    final nativeCalls = <NativeCallSnapshot>[nativeForInvite('invite_timeout')];
    await claimCallkitOwnedInvite(tester, 'invite_timeout', nativeCalls);

    await manager.handleSystemTimeoutInvite(
      inviteId: 'invite_timeout',
      source: 'callkit_timeout',
    );
    await tester.pump();

    await expectIdleAfterCallkitTerminal(
        tester, 'invite_after_timeout', nativeCalls);
  });

  testWidgets('CallKit-owned failed snapshot releases lifecycle',
      (tester) async {
    await tester.pumpWidget(buildHarness());
    final nativeCalls = <NativeCallSnapshot>[nativeForInvite('invite_failed')];
    await manager.bindIncomingInviteListener();
    await claimCallkitOwnedInvite(tester, 'invite_failed', nativeCalls);

    await firestore.collection('callInvites').doc('invite_failed').set({
      'status': CallInviteStatus.failed.name,
      'endedAt': Timestamp.now(),
    }, SetOptions(merge: true));
    for (var i = 0; i < 20; i += 1) {
      await tester.pump(const Duration(milliseconds: 100));
      if (manager.debugSnapshot()['sessionIdle'] == true) break;
    }

    await expectIdleAfterCallkitTerminal(
        tester, 'invite_after_failed', nativeCalls);
  });

  testWidgets('Firestore cancel marks terminal ledger before late push',
      (tester) async {
    await tester.pumpWidget(buildHarness());
    final nativeCalls = <NativeCallSnapshot>[
      nativeForInvite('invite_cancel_ledger'),
    ];
    final markedStates = <String>[];
    final presented = <String>[];
    configureIosCallkitOnly(
      nativeCalls: nativeCalls,
      markedStates: markedStates,
      presentedInvites: presented,
    );
    await manager.bindIncomingInviteListener();
    await seedInvite('invite_cancel_ledger');

    await manager.handleNotificationInviteTap(
      inviteId: 'invite_cancel_ledger',
      channel: 'channel_invite_cancel_ledger',
      isVideo: false,
      fromName: callerName,
      fromUid: callerUid,
      source: 'firestore_first',
    );
    await firestore.collection('callInvites').doc('invite_cancel_ledger').set({
      'status': CallInviteStatus.cancelled.name,
      'endedAt': Timestamp.now(),
      'channel': 'channel_invite_cancel_ledger',
    }, SetOptions(merge: true));
    for (var i = 0; i < 20; i += 1) {
      await tester.pump(const Duration(milliseconds: 100));
      if (manager.debugSnapshot()['sessionIdle'] == true) break;
    }

    final latePush = manager.handleNotificationInviteTap(
      inviteId: 'invite_cancel_ledger',
      channel: 'channel_invite_cancel_ledger',
      isVideo: false,
      fromName: callerName,
      fromUid: callerUid,
      source: 'late_push_after_cancel',
    );
    await tester.pump(const Duration(seconds: 1));
    await latePush;

    expect(markedStates, contains('terminal'));
    expect(nativeCalls, isEmpty);
    expect(presented, isEmpty);
    expect(manager.debugSnapshot()['sessionIdle'], isTrue);
    expect(manager.debugSnapshot()['flutterIncomingPromptCount'], 0);
  });

  testWidgets('Firestore failed marks terminal ledger before late push',
      (tester) async {
    await tester.pumpWidget(buildHarness());
    final nativeCalls = <NativeCallSnapshot>[
      nativeForInvite('invite_failed_ledger'),
    ];
    final markedStates = <String>[];
    final presented = <String>[];
    configureIosCallkitOnly(
      nativeCalls: nativeCalls,
      markedStates: markedStates,
      presentedInvites: presented,
    );
    await manager.bindIncomingInviteListener();
    await seedInvite('invite_failed_ledger');

    await manager.handleNotificationInviteTap(
      inviteId: 'invite_failed_ledger',
      channel: 'channel_invite_failed_ledger',
      isVideo: false,
      fromName: callerName,
      fromUid: callerUid,
      source: 'firestore_first',
    );
    await firestore.collection('callInvites').doc('invite_failed_ledger').set({
      'status': CallInviteStatus.failed.name,
      'endedAt': Timestamp.now(),
      'channel': 'channel_invite_failed_ledger',
    }, SetOptions(merge: true));
    for (var i = 0; i < 20; i += 1) {
      await tester.pump(const Duration(milliseconds: 100));
      if (manager.debugSnapshot()['sessionIdle'] == true) break;
    }

    final latePush = manager.handleNotificationInviteTap(
      inviteId: 'invite_failed_ledger',
      channel: 'channel_invite_failed_ledger',
      isVideo: false,
      fromName: callerName,
      fromUid: callerUid,
      source: 'late_push_after_failed',
    );
    await tester.pump(const Duration(seconds: 1));
    await latePush;

    expect(markedStates, contains('terminal'));
    expect(nativeCalls, isEmpty);
    expect(presented, isEmpty);
    expect(manager.debugSnapshot()['sessionIdle'], isTrue);
    expect(manager.debugSnapshot()['flutterIncomingPromptCount'], 0);
  });

  testWidgets('native PushKit wins fallback race through existing outcome',
      (tester) async {
    await tester.pumpWidget(buildHarness());
    final nativeCalls = <NativeCallSnapshot>[];
    var nativePresentationTotal = 0;
    configureIosCallkitOnly(
      nativeCalls: nativeCalls,
      presenter: (payload) async {
        if (nativeCalls.isEmpty) {
          nativeCalls.add(nativeForInvite(payload.inviteId));
          nativePresentationTotal += 1;
        }
        return true;
      },
    );
    await seedInvite('invite_push_wins_race');

    final handling = manager.handleNotificationInviteTap(
      inviteId: 'invite_push_wins_race',
      channel: 'channel_invite_push_wins_race',
      isVideo: false,
      fromName: callerName,
      fromUid: callerUid,
      source: 'firestore_first_race',
    );
    await tester.pump(const Duration(seconds: 1));
    await handling;

    expect(nativePresentationTotal, 1);
    expect(nativeCalls, hasLength(1));
    expect(manager.debugSnapshot()['incomingUiOwner'],
        IncomingUiOwner.callkit.name);
    expect(manager.debugSnapshot()['flutterIncomingPromptCount'], 0);
  });

  testWidgets('Dart fallback wins then PushKit uses existing native owner',
      (tester) async {
    await tester.pumpWidget(buildHarness());
    final nativeCalls = <NativeCallSnapshot>[];
    var nativePresentationTotal = 0;
    configureIosCallkitOnly(
      nativeCalls: nativeCalls,
      presenter: (payload) async {
        if (nativeCalls.isEmpty) {
          nativeCalls.add(nativeForInvite(payload.inviteId));
          nativePresentationTotal += 1;
        }
        return true;
      },
    );
    await seedInvite('invite_dart_wins_race');

    final first = manager.handleNotificationInviteTap(
      inviteId: 'invite_dart_wins_race',
      channel: 'channel_invite_dart_wins_race',
      isVideo: false,
      fromName: callerName,
      fromUid: callerUid,
      source: 'firestore_fallback_first',
    );
    await tester.pump(const Duration(seconds: 1));
    await first;
    await manager.handleNotificationInviteTap(
      inviteId: 'invite_dart_wins_race',
      channel: 'channel_invite_dart_wins_race',
      isVideo: false,
      fromName: callerName,
      fromUid: callerUid,
      source: 'pushkit_after_dart_fallback',
    );

    expect(nativePresentationTotal, 1);
    expect(nativeCalls, hasLength(1));
    expect(manager.debugSnapshot()['incomingUiOwner'],
        IncomingUiOwner.callkit.name);
    expect(manager.debugSnapshot()['flutterIncomingPromptCount'], 0);
  });

  testWidgets('Dart fallback continuation cannot downgrade accepted ledger',
      (tester) async {
    await tester.pumpWidget(buildHarness());
    final nativeCalls = <NativeCallSnapshot>[];
    final markedStates = <String>[];
    final presentationStarted = Completer<void>();
    final finishPresentation = Completer<bool>();
    configureIosCallkitOnly(
      nativeCalls: nativeCalls,
      markedStates: markedStates,
      presenter: (payload) {
        if (!presentationStarted.isCompleted) {
          presentationStarted.complete();
        }
        return finishPresentation.future;
      },
    );
    await seedInvite('invite_accept_during_fallback');

    final handling = manager.handleNotificationInviteTap(
      inviteId: 'invite_accept_during_fallback',
      channel: 'channel_invite_accept_during_fallback',
      isVideo: false,
      fromName: callerName,
      fromUid: callerUid,
      source: 'firestore_fallback_before_accept',
    );
    await tester.pump(const Duration(seconds: 1));
    await presentationStarted.future;

    markedStates.add('accepted');
    finishPresentation.complete(true);
    await handling;

    expect(markedStates, ['accepted']);
    expect(manager.debugSnapshot()['incomingUiOwner'],
        IncomingUiOwner.callkit.name);
    expect(manager.debugSnapshot()['flutterIncomingPromptCount'], 0);
  });

  testWidgets('Dart fallback continuation cannot downgrade terminal ledger',
      (tester) async {
    await tester.pumpWidget(buildHarness());
    final nativeCalls = <NativeCallSnapshot>[];
    final markedStates = <String>[];
    final presentationStarted = Completer<void>();
    final finishPresentation = Completer<bool>();
    configureIosCallkitOnly(
      nativeCalls: nativeCalls,
      markedStates: markedStates,
      presenter: (payload) {
        if (!presentationStarted.isCompleted) {
          presentationStarted.complete();
        }
        return finishPresentation.future;
      },
    );
    await seedInvite('invite_terminal_during_fallback');

    final handling = manager.handleNotificationInviteTap(
      inviteId: 'invite_terminal_during_fallback',
      channel: 'channel_invite_terminal_during_fallback',
      isVideo: false,
      fromName: callerName,
      fromUid: callerUid,
      source: 'firestore_fallback_before_terminal',
    );
    await tester.pump(const Duration(seconds: 1));
    await presentationStarted.future;

    markedStates.add('terminal');
    finishPresentation.complete(true);
    await handling;

    expect(markedStates, ['terminal']);
    expect(manager.debugSnapshot()['incomingUiOwner'],
        IncomingUiOwner.callkit.name);
    expect(manager.debugSnapshot()['flutterIncomingPromptCount'], 0);
  });

  test('native source coordinates APNS fallback and PushKit presentation', () {
    final source = File('ios/Runner/AppDelegate.swift').readAsStringSync();
    expect(source, contains('ensureIncomingCallkit('));
    expect(source, contains('call.method == "ensureIncomingCallkit"'));
    expect(source, contains('let ensureOutcome = ensureIncomingCallkit('));
    expect(source, contains('return "suppressedAccepted"'));
    expect(source, contains('return "suppressedActive"'));
    expect(source, contains('return "suppressedTerminal"'));

    final declineIndex = source.indexOf('if actionId == "DECLINE_CALL"');
    final declineMarkIndex = source.indexOf(
      'markCallkitPresentationState(callkitId: callkitId, state: "terminal")',
      declineIndex,
    );
    final declineStoreIndex =
        source.indexOf('storeCallkitEvent(', declineIndex);
    expect(declineMarkIndex, greaterThan(declineIndex));
    expect(declineMarkIndex, lessThan(declineStoreIndex));

    final acceptStoreIndex = source.indexOf('storeAcceptedCallData(');
    final acceptMarkIndex = source.lastIndexOf(
      'markCallkitPresentationState(callkitId: callkitId, state: "accepted")',
      acceptStoreIndex,
    );
    expect(acceptMarkIndex, greaterThan(declineStoreIndex));
    expect(acceptMarkIndex, lessThan(acceptStoreIndex));
  });

  test('native source bridges CallKit accept to Flutter before fulfilling', () {
    final source = File('ios/Runner/AppDelegate.swift').readAsStringSync();
    final onAcceptIndex = source.indexOf('func onAccept(');
    final storeIndex = source.indexOf('storeAcceptedCall(call)', onAcceptIndex);
    final eventIndex =
        source.indexOf('storeCallkitEvent("accept"', onAcceptIndex);
    final ledgerIndex = source.indexOf(
      'markCallkitPresentationState(callkitId: call.data.uuid, state: "accepted")',
      onAcceptIndex,
    );
    final bridgeIndex =
        source.indexOf('method: "callkitAcceptedNative"', onAcceptIndex);
    final fulfillIndex = source.indexOf('action.fulfill()', onAcceptIndex);

    expect(onAcceptIndex, isNonNegative);
    expect(storeIndex, greaterThan(onAcceptIndex));
    expect(eventIndex, greaterThan(storeIndex));
    expect(ledgerIndex, greaterThan(eventIndex));
    expect(bridgeIndex, greaterThan(ledgerIndex));
    expect(fulfillIndex, greaterThan(bridgeIndex));
  });

  test('native source keeps CallKit ledger transitions monotonic', () {
    final source = File('ios/Runner/AppDelegate.swift').readAsStringSync();

    expect(source, contains('callkitPresentationStateRank'));
    expect(source, contains('canApplyCallkitPresentationTransition'));
    expect(source, contains('case "presenting", "presented":'));
    expect(source, contains('case "accepted":'));
    expect(source, contains('case "active":'));
    expect(source, contains('case "terminal":'));
    expect(source,
        contains('if current == "terminal" { return next == "terminal" }'));
    expect(source, contains('if nextRank < currentRank { return false }'));
    expect(
        source,
        contains(
            'if current == "active" && next == "accepted" { return false }'));

    final guardIndex = source.indexOf(
      'guard canApplyCallkitPresentationTransition',
    );
    final ledgerWriteIndex =
        source.indexOf('current["state"] = normalizedState');
    expect(guardIndex, isNonNegative);
    expect(ledgerWriteIndex, greaterThan(guardIndex));
  });

  test('native source leases presentation before showing CallKit', () {
    final source = File('ios/Runner/AppDelegate.swift').readAsStringSync();

    expect(source, contains('callkitPresentationLeaseGraceSeconds'));
    expect(source, contains('callkitPresentationMaxAttempts'));
    expect(source, contains('beginCallkitPresentationLease'));
    expect(source, contains('callkitPresentationLeaseFresh'));
    expect(source, contains('current["state"] = "presenting"'));
    expect(source, contains('current["presentationAttempts"] = attempts + 1'));
    expect(source, contains('presentation_retry_exhausted=true'));

    final freshLeaseIndex = source.indexOf(
      'if callkitPresentationLeaseFresh(callkitId: callkitId)',
    );
    final beginLeaseIndex = source.indexOf(
      'guard beginCallkitPresentationLease(callkitId: callkitId)',
    );
    final showIndex = source.indexOf('showCallkitIncoming(');
    final presentedMarkIndex = source.indexOf(
      'markCallkitPresentationState(callkitId: callkitId, state: "presented")',
      showIndex,
    );
    expect(freshLeaseIndex, isNonNegative);
    expect(beginLeaseIndex, greaterThan(freshLeaseIndex));
    expect(showIndex, greaterThan(beginLeaseIndex));
    expect(presentedMarkIndex, greaterThan(showIndex));
  });

  test('Dart iOS fallback does not directly show CallKit', () {
    final source =
        File('lib/services/notification_service.dart').readAsStringSync();
    expect(source, contains("'ensureIncomingCallkit'"));
    expect(
        source, isNot(contains('FlutterCallkitIncoming.showCallkitIncoming')));
  });

  test('Dart manager does not mark presented after native ensure', () {
    final source =
        File('lib/services/call_session_manager.dart').readAsStringSync();
    expect(source, isNot(contains("state: 'presented'")));
    expect(source, isNot(contains('callkit_fallback_presented')));
  });

  testWidgets(
      'foreground incoming without native CallKit uses Flutter fallback',
      (tester) async {
    await tester.pumpWidget(buildHarness());
    await seedInvite('invite_flutter');
    manager.configure(
      navigatorKey: navigatorKey,
      appForegroundProvider: () async => true,
      listNativeCalls: () async => const <NativeCallSnapshot>[],
    );

    final promptFuture = manager.handleNotificationInviteTap(
      inviteId: 'invite_flutter',
      channel: 'channel_invite_flutter',
      isVideo: false,
      fromName: callerName,
      fromUid: callerUid,
      source: 'foreground_test',
    );
    for (var attempt = 0;
        attempt < 20 && !(navigatorKey.currentState?.canPop() ?? false);
        attempt += 1) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(
      manager.debugSnapshot()['incomingUiOwner'],
      IncomingUiOwner.flutter.name,
    );
    expect(manager.debugSnapshot()['activePromptCount'], 1);
    expect(navigatorKey.currentState?.canPop(), isTrue);
    navigatorKey.currentState!.pop(false);
    await tester.pump();
    await tester.runAsync(
      () => promptFuture.timeout(const Duration(seconds: 5)),
    );
  });

  testWidgets('pending invite re-resolves to CallKit owner after teardown',
      (tester) async {
    await tester.pumpWidget(buildHarness());
    final nativeCalls = <NativeCallSnapshot>[];
    manager.configure(
      navigatorKey: navigatorKey,
      appForegroundProvider: () async => true,
      listNativeCalls: () async => List<NativeCallSnapshot>.from(nativeCalls),
    );
    await seedInvite('invite_b');
    await manager.debugCreateHeldCallRouteForTest(
      inviteId: 'invite_a',
      channel: 'channel_invite_a',
    );
    await manager.debugMarkHeldRouteTerminalForTest('invite_a');
    await manager.debugRunPreflightForTest('pending_callkit_preflight');

    nativeCalls.add(nativeForInvite('invite_b'));
    await manager.handleNotificationInviteTap(
      inviteId: 'invite_b',
      channel: 'channel_invite_b',
      isVideo: false,
      fromName: callerName,
      fromUid: callerUid,
      source: 'pending_callkit',
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(manager.debugSnapshot()['pendingIncomingPresent'], isTrue);
    expect(find.text('Incoming Audio Call'), findsNothing);

    final closeFuture = manager.debugCloseHeldRouteForTest('invite_a');
    await tester.pump(const Duration(milliseconds: 300));
    await closeFuture;
    await tester.pump(const Duration(milliseconds: 350));

    final snapshot = manager.debugSnapshot();
    expect(snapshot['incomingUiOwner'], IncomingUiOwner.callkit.name);
    expect(snapshot['activePromptCount'], 1);
    expect(find.text('Incoming Audio Call'), findsNothing);
  });

  testWidgets('pending invite falls back to Flutter when no CallKit owner',
      (tester) async {
    await tester.pumpWidget(buildHarness());
    manager.configure(
      navigatorKey: navigatorKey,
      appForegroundProvider: () async => true,
      listNativeCalls: () async => const <NativeCallSnapshot>[],
    );
    await seedInvite('invite_b');
    await manager.debugCreateHeldCallRouteForTest(
      inviteId: 'invite_a',
      channel: 'channel_invite_a',
    );
    await manager.debugMarkHeldRouteTerminalForTest('invite_a');
    await manager.debugRunPreflightForTest('pending_flutter_preflight');

    await manager.handleNotificationInviteTap(
      inviteId: 'invite_b',
      channel: 'channel_invite_b',
      isVideo: false,
      fromName: callerName,
      fromUid: callerUid,
      source: 'pending_flutter',
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(manager.debugSnapshot()['pendingIncomingPresent'], isTrue);

    final closeFuture = manager.debugCloseHeldRouteForTest('invite_a');
    await tester.pump(const Duration(milliseconds: 300));
    await closeFuture;
    for (var attempt = 0;
        attempt < 20 && find.text('Incoming Audio Call').evaluate().isEmpty;
        attempt += 1) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    final snapshot = manager.debugSnapshot();
    expect(snapshot['incomingUiOwner'], IncomingUiOwner.flutter.name);
    expect(find.text('Incoming Audio Call'), findsOneWidget);
    navigatorKey.currentState!.pop(false);
    await tester.pump();
  });

  testWidgets('old terminal callback cannot clear newer pending owner',
      (tester) async {
    await tester.pumpWidget(buildHarness());
    manager.configure(
      navigatorKey: navigatorKey,
      appForegroundProvider: () async => true,
      listNativeCalls: () async => const <NativeCallSnapshot>[],
    );
    await seedInvite('invite_b');
    await manager.debugCreateHeldCallRouteForTest(
      inviteId: 'invite_a',
      channel: 'channel_invite_a',
    );
    await manager.debugMarkHeldRouteTerminalForTest('invite_a');
    await manager.debugRunPreflightForTest('stale_terminal_preflight');

    await manager.handleNotificationInviteTap(
      inviteId: 'invite_b',
      channel: 'channel_invite_b',
      isVideo: false,
      fromName: callerName,
      fromUid: callerUid,
      source: 'stale_terminal',
    );
    final closeFuture = manager.debugCloseHeldRouteForTest('invite_a');
    await tester.pump(const Duration(milliseconds: 300));
    await closeFuture;
    for (var attempt = 0;
        attempt < 20 && find.text('Incoming Audio Call').evaluate().isEmpty;
        attempt += 1) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    await manager.debugCloseHeldRouteForTest('invite_a');
    await manager.debugRunPreflightForTest('old_terminal_callback');
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      manager.debugSnapshot()['incomingUiOwner'],
      IncomingUiOwner.flutter.name,
    );
    expect(find.text('Incoming Audio Call'), findsOneWidget);
    navigatorKey.currentState!.pop(false);
    await tester.pump();
  });

  testWidgets('Flutter decline closes matching native CallKit call',
      (tester) async {
    await tester.pumpWidget(buildHarness());
    await seedInvite('invite_decline');
    final ended = <String>[];
    manager.configure(
      navigatorKey: navigatorKey,
      appForegroundProvider: () async => true,
      listNativeCalls: () async => const <NativeCallSnapshot>[
        NativeCallSnapshot(
          callkitId: '696e7669-7465-4465-a36c-696e65696e76',
          inviteId: 'invite_decline',
          channel: 'channel_invite_decline',
        ),
      ],
      endNativeCall: (callkitId) async {
        ended.add(callkitId);
      },
    );

    await manager.declineInvite(
      inviteId: 'invite_decline',
      source: 'flutter_decline_test',
    );

    final invite =
        await firestore.collection('callInvites').doc('invite_decline').get();
    expect(invite.data()?['status'], CallInviteStatus.declined.name);
    expect(ended, isNotEmpty);
  });

  testWidgets('accepted recovery without navigator remains pending',
      (tester) async {
    var cleared = 0;
    manager.configure(
      clearStoredAcceptedCallRecovery: () async {
        cleared += 1;
      },
    );
    await seedInvite('invite_pending', status: CallInviteStatus.accepted);

    final result = await manager.handleRecoveredAcceptedInvite(
      inviteId: 'invite_pending',
      channel: 'channel_invite_pending',
      isVideo: false,
      fromName: callerName,
      fromUid: callerUid,
    );

    expect(result, AcceptedCallRecoveryResult.pendingNavigator);
    expect(cleared, 0);
    expect(manager.debugSnapshot()['acceptedRecoveryPending'], isTrue);
    expect(manager.debugSnapshot()['hiddenSessionDetected'], isFalse);
  });

  testWidgets('terminal accepted recovery closes native call and clears record',
      (tester) async {
    await tester.pumpWidget(buildHarness());
    await seedInvite('invite_terminal', status: CallInviteStatus.cancelled);
    var cleared = 0;
    final ended = <String>[];
    manager.configure(
      navigatorKey: navigatorKey,
      appForegroundProvider: () async => true,
      clearStoredAcceptedCallRecovery: () async {
        cleared += 1;
      },
      listNativeCalls: () async => const <NativeCallSnapshot>[
        NativeCallSnapshot(
          callkitId: '696e7669-7465-5465-bd69-6e616c696e76',
          inviteId: 'invite_terminal',
          channel: 'channel_invite_terminal',
        ),
      ],
      endNativeCall: (callkitId) async {
        ended.add(callkitId);
      },
    );

    final result = await manager.handleRecoveredAcceptedInvite(
      inviteId: 'invite_terminal',
      channel: 'channel_invite_terminal',
      isVideo: false,
      fromName: callerName,
      fromUid: callerUid,
    );

    expect(result, AcceptedCallRecoveryResult.terminal);
    expect(cleared, 1);
    expect(ended, isNotEmpty);
    expect(manager.debugSnapshot()['acceptedRecoveryAcknowledged'], isTrue);
    expect(find.text('Incoming Audio Call'), findsNothing);
  });

  testWidgets('outgoing reservation lost during preflight writes no invite',
      (tester) async {
    await tester.pumpWidget(buildHarness());
    HelperlyTestRuntime.configureForTest(
      firestore: firestore,
      currentUid: callerUid,
      currentDisplayName: callerName,
    );
    manager.configure(
      navigatorKey: navigatorKey,
      appForegroundProvider: () async => true,
      listNativeCalls: () async {
        manager.debugInvalidateLifecycleForTest();
        return const <NativeCallSnapshot>[];
      },
    );

    final started = await manager.startOutgoingCall(
      navigatorKey.currentContext!,
      toUid: calleeUid,
      toName: calleeName,
      isVideo: false,
      openScreen: false,
    );

    final invites = await firestore.collection('callInvites').get();
    expect(started, isFalse);
    expect(invites.docs, isEmpty);
  });

  testWidgets('outgoing reservation lost after invite write cancels orphan',
      (tester) async {
    await tester.pumpWidget(buildHarness());
    HelperlyTestRuntime.configureForTest(
      firestore: firestore,
      currentUid: callerUid,
      currentDisplayName: callerName,
    );
    manager.configure(
      navigatorKey: navigatorKey,
      appForegroundProvider: () async => true,
      listNativeCalls: () async => const <NativeCallSnapshot>[],
      afterOutgoingInviteWriteForTest: () async {
        manager.debugInvalidateLifecycleForTest();
      },
    );

    final started = await manager.startOutgoingCall(
      navigatorKey.currentContext!,
      toUid: calleeUid,
      toName: calleeName,
      isVideo: false,
      openScreen: false,
    );

    final invites = await firestore.collection('callInvites').get();
    expect(started, isFalse);
    expect(invites.docs, hasLength(1));
    expect(
      invites.docs.single.data()['status'],
      CallInviteStatus.cancelled.name,
    );
    expect(manager.debugSnapshot()['activeSessionPresent'], isFalse);
    expect(manager.debugSnapshot()['orphanInviteCancelledCount'], 1);
  });

  testWidgets('reportRemoteJoined after terminal cannot resurrect session',
      (tester) async {
    await tester.pumpWidget(buildHarness());
    await seedInvite('invite_a', status: CallInviteStatus.connected);
    await manager.debugCreateHeldCallRouteForTest(
      inviteId: 'invite_a',
      channel: 'channel_invite_a',
    );

    await manager.endCallFromLocalUser(
      inviteId: 'invite_a',
      source: 'test_end',
    );
    await manager.reportRemoteJoined(inviteId: 'invite_a', isCaller: true);

    final invite =
        await firestore.collection('callInvites').doc('invite_a').get();
    final snapshot = manager.debugSnapshot();
    expect(snapshot['phase'], CallSessionPhase.terminal.name);
    expect(
      snapshot['callLifecycleState'],
      isIn(<String>[
        CallV2CallLifecycleState.ending.name,
        CallV2CallLifecycleState.teardown.name,
      ]),
    );
    expect(invite.data()?['status'], CallInviteStatus.ended.name);
  });

  testWidgets('reportAgoraJoinSuccess after ending is ignored', (tester) async {
    await tester.pumpWidget(buildHarness());
    await seedInvite('invite_a', status: CallInviteStatus.connected);
    await manager.debugCreateHeldCallRouteForTest(
      inviteId: 'invite_a',
      channel: 'channel_invite_a',
    );

    await manager.endCallFromLocalUser(
      inviteId: 'invite_a',
      source: 'test_end',
    );
    await manager.reportAgoraJoinSuccess(inviteId: 'invite_a', isCaller: true);

    final snapshot = manager.debugSnapshot();
    expect(snapshot['phase'], CallSessionPhase.terminal.name);
    expect(
      snapshot['callLifecycleState'],
      isIn(<String>[
        CallV2CallLifecycleState.ending.name,
        CallV2CallLifecycleState.teardown.name,
      ]),
    );
  });

  testWidgets('reportCallScreenBegan after ending does not write joining',
      (tester) async {
    await tester.pumpWidget(buildHarness());
    await seedInvite('invite_a', status: CallInviteStatus.connected);
    await manager.debugCreateHeldCallRouteForTest(
      inviteId: 'invite_a',
      channel: 'channel_invite_a',
    );

    await manager.endCallFromLocalUser(
      inviteId: 'invite_a',
      source: 'test_end',
    );
    await manager.reportCallScreenBegan(inviteId: 'invite_a', isCaller: false);

    final invite =
        await firestore.collection('callInvites').doc('invite_a').get();
    final snapshot = manager.debugSnapshot();
    expect(snapshot['phase'], CallSessionPhase.terminal.name);
    expect(
        snapshot['callLifecycleState'], CallV2CallLifecycleState.ending.name);
    expect(invite.data()?['status'], CallInviteStatus.ended.name);
  });

  testWidgets('late Firestore connected snapshot after local end is ignored',
      (tester) async {
    await tester.pumpWidget(buildHarness());
    HelperlyTestRuntime.configureForTest(
      firestore: firestore,
      currentUid: callerUid,
      currentDisplayName: callerName,
    );
    manager.configure(
      navigatorKey: navigatorKey,
      appForegroundProvider: () async => true,
      listNativeCalls: () async => const <NativeCallSnapshot>[],
    );

    final started = await manager.startOutgoingCall(
      navigatorKey.currentContext!,
      toUid: calleeUid,
      toName: calleeName,
      isVideo: false,
      openScreen: false,
    );
    expect(started, isTrue);
    final inviteId =
        (await firestore.collection('callInvites').get()).docs.single.id;

    await manager.reportRemoteJoined(inviteId: inviteId, isCaller: true);
    await manager.endCallFromLocalUser(inviteId: inviteId, source: 'test_end');
    await firestore.collection('callInvites').doc(inviteId).set({
      'status': CallInviteStatus.connected.name,
      'connectedAt': Timestamp.now(),
    }, SetOptions(merge: true));
    await tester.pump(const Duration(milliseconds: 100));

    final snapshot = manager.debugSnapshot();
    expect(snapshot['phase'], CallSessionPhase.terminal.name);
    expect(snapshot['status'], CallInviteStatus.ended.name);
    expect(
      snapshot['callLifecycleState'],
      isIn(<String>[
        CallV2CallLifecycleState.ending.name,
        CallV2CallLifecycleState.teardown.name,
      ]),
    );
  });

  testWidgets('fifteen rapid manager lifecycles ignore delayed progress',
      (tester) async {
    await tester.pumpWidget(buildHarness());

    var previousGeneration = 0;
    for (var i = 1; i <= 15; i += 1) {
      final inviteId = 'stress_$i';
      await seedInvite(inviteId, status: CallInviteStatus.connected);
      final generation = await manager.debugCreateHeldCallRouteForTest(
        inviteId: inviteId,
        channel: 'channel_$inviteId',
      );
      expect(generation, greaterThan(previousGeneration));
      previousGeneration = generation;

      await manager.endCallFromLocalUser(inviteId: inviteId, source: 'stress');
      await manager.reportAgoraJoinSuccess(inviteId: inviteId, isCaller: true);
      await manager.reportRemoteJoined(inviteId: inviteId, isCaller: true);
      await firestore.collection('callInvites').doc(inviteId).set({
        'status': CallInviteStatus.connected.name,
        'connectedAt': Timestamp.now(),
      }, SetOptions(merge: true));
      await tester.pump(const Duration(milliseconds: 20));

      expect(manager.debugSnapshot()['phase'], CallSessionPhase.terminal.name);
      expect(
        manager.debugSnapshot()['callLifecycleState'],
        CallV2CallLifecycleState.ending.name,
      );
      await manager.debugCloseHeldRouteForTest(inviteId);
      await tester.pump();
      expect(manager.debugSnapshot()['activeSessionPresent'], isFalse);
      expect(manager.debugSnapshot()['callLifecycleState'], 'idle');
    }
  });
}
