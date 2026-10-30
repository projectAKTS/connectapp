import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connect_app/screens/call/agora_call_screen.dart';
import 'package:connect_app/services/call_reconnect_watch.dart';
import 'package:connect_app/services/call_session_manager.dart';
import 'package:connect_app/services/helperly_test_runtime.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// F3: a connected call survives a short network drop, like WhatsApp.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const callerUid = 'reconnect_caller';
  const calleeUid = 'reconnect_callee';
  const dropped = 'UserOfflineReasonType.userOfflineDropped';
  late FakeFirebaseFirestore firestore;
  late CallSessionManager manager;

  Future<void> seedConnectedInvite(String inviteId) async {
    await firestore.collection('callInvites').doc(inviteId).set(
      <String, dynamic>{
        'fromUid': callerUid,
        'toUid': calleeUid,
        'fromName': 'Reconnect Caller',
        'toName': 'Reconnect Callee',
        'channel': 'channel_$inviteId',
        'isVideo': false,
        'status': CallInviteStatus.connected.name,
        'callerStage': CallInviteStatus.connected.name,
        'calleeStage': CallInviteStatus.connected.name,
        'createdAt': Timestamp.now(),
      },
    );
  }

  Future<Map<String, dynamic>> invite(String inviteId) async {
    final snapshot =
        await firestore.collection('callInvites').doc(inviteId).get();
    return snapshot.data()!;
  }

  Future<void> showConnectedCall(
    WidgetTester tester,
    String inviteId, {
    bool isVideo = false,
  }) async {
    await seedConnectedInvite(inviteId);
    final generation = await manager.debugCreateHeldCallRouteForTest(
      inviteId: inviteId,
      channel: 'channel_$inviteId',
      acceptedCallkitId: 'exact_$inviteId',
      status: CallInviteStatus.connected,
      isCaller: true,
      isVideo: isVideo,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              key: const Key('open-call-screen'),
              onPressed: () {
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    fullscreenDialog: true,
                    builder: (_) => AgoraCallScreen(
                      channelName: 'channel_$inviteId',
                      isVideo: isVideo,
                      otherUserName: 'Reconnect User',
                      inviteId: inviteId,
                      acceptedCallkitId: 'exact_$inviteId',
                      lifecycleGeneration: generation,
                      isCaller: true,
                      skipRuntimeSetupForTest: true,
                      startLoadedForTest: true,
                    ),
                  ),
                );
              },
              child: const Text('Home'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('open-call-screen')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('call-v2-hangup')), findsOne);
  }

  Future<void> closeCall(WidgetTester tester, String inviteId) async {
    await manager.endCallFromLocalUser(inviteId: inviteId);
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 40));
    await tester.pumpAndSettle();
  }

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    HelperlyTestRuntime.configureForTest(
      firestore: firestore,
      currentUid: callerUid,
      currentDisplayName: 'Reconnect Caller',
    );
    manager = CallSessionManager.instance;
    await manager.clearForSignedOut();
    await manager.forceIdleForTest();
    HelperlyTestRuntime.configureForTest(
      firestore: firestore,
      currentUid: callerUid,
      currentDisplayName: 'Reconnect Caller',
    );
    manager.configure(
      listNativeCalls: () async => const <NativeCallSnapshot>[],
      endNativeCall: (_) async {},
      markNativeInviteState: ({
        required String inviteId,
        required String channel,
        required String callkitId,
        required String state,
      }) async {},
      clearStoredAcceptedCallRecovery: ({
        required String inviteId,
        required String callkitId,
      }) async {},
      appForegroundProvider: () async => true,
    );
  });

  tearDown(() async {
    await manager.forceIdleForTest();
    HelperlyTestRuntime.clear();
  });

  testWidgets('a dropped remote that rejoins keeps the call connected',
      (tester) async {
    const inviteId = 'reconnect_rejoin';
    await showConnectedCall(tester, inviteId);

    await manager.reportRemoteOffline(
      inviteId: inviteId,
      wasConnected: true,
      isCaller: true,
      reason: dropped,
    );
    await tester.pump();
    expect(find.text('Reconnecting…'), findsOne);
    expect(find.text('Call ended'), findsNothing);
    expect((await invite(inviteId))['status'], CallInviteStatus.connected.name);

    await tester.pump(const Duration(seconds: 15));
    await manager.reportRemoteJoined(inviteId: inviteId, isCaller: true);
    await tester.pump();
    expect(find.text('Reconnecting…'), findsNothing);

    await tester.pump(CallReconnectWatch.defaultRemoteGrace * 2);
    expect(find.text('Call ended'), findsNothing);
    expect((await invite(inviteId))['status'], CallInviteStatus.connected.name);

    await closeCall(tester, inviteId);
  });

  testWidgets('a dropped remote that stays away ends after the grace',
      (tester) async {
    const inviteId = 'reconnect_grace_expired';
    await showConnectedCall(tester, inviteId, isVideo: true);

    await manager.reportRemoteOffline(
      inviteId: inviteId,
      wasConnected: true,
      isCaller: true,
      reason: dropped,
    );
    await tester.pump(
        CallReconnectWatch.defaultRemoteGrace - const Duration(seconds: 1));
    expect(find.text('Reconnecting…'), findsOne);
    expect((await invite(inviteId))['status'], CallInviteStatus.connected.name);

    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 100));
    final data = await invite(inviteId);
    expect(data['status'], CallInviteStatus.ended.name);
    expect(data['endReason'], 'remote_left:$dropped:grace_expired');
    expect(find.text('Call ended'), findsOne);
    expect(manager.reconnectStatus.value, isNull);

    await tester.pump(const Duration(seconds: 40));
    await tester.pumpAndSettle();
  });

  testWidgets('a remote hang-up still ends the call at once', (tester) async {
    const inviteId = 'reconnect_quit';
    await showConnectedCall(tester, inviteId);

    await manager.reportRemoteOffline(
      inviteId: inviteId,
      wasConnected: true,
      isCaller: true,
      reason: 'UserOfflineReasonType.userOfflineQuit',
    );
    await tester.pump();
    expect(find.text('Call ended'), findsOne);
    expect(find.text('Reconnecting…'), findsNothing);
    expect((await invite(inviteId))['status'], CallInviteStatus.ended.name);

    await tester.pump(const Duration(seconds: 40));
    await tester.pumpAndSettle();
  });

  testWidgets('a local connection that never recovers ends the call',
      (tester) async {
    const inviteId = 'reconnect_local_limit';
    await showConnectedCall(tester, inviteId);

    manager.reportLocalConnectionState(inviteId: inviteId, reconnecting: true);
    await tester.pump();
    expect(find.text('Reconnecting…'), findsOne);

    await tester.pump(const Duration(seconds: 10));
    manager.reportLocalConnectionState(inviteId: inviteId, reconnecting: false);
    await tester.pump();
    expect(find.text('Reconnecting…'), findsNothing);

    manager.reportLocalConnectionState(inviteId: inviteId, reconnecting: true);
    await tester.pump(CallReconnectWatch.defaultLocalLimit);
    await tester.pump(const Duration(milliseconds: 100));
    final data = await invite(inviteId);
    expect(data['status'], CallInviteStatus.ended.name);
    expect(data['endReason'], 'local_network_lost');

    await tester.pump(const Duration(seconds: 40));
    await tester.pumpAndSettle();
  });

  testWidgets('frozen remote audio shows reconnecting', (tester) async {
    const inviteId = 'reconnect_frozen';
    await showConnectedCall(tester, inviteId);

    manager.reportRemoteAudioFrozen(inviteId: inviteId, frozen: true);
    await tester.pump(CallReconnectWatch.defaultStallDelay);
    await tester.pump();
    expect(find.text('Reconnecting…'), findsOne);

    manager.reportRemoteAudioFrozen(inviteId: inviteId, frozen: false);
    await tester.pump();
    expect(find.text('Reconnecting…'), findsNothing);

    await closeCall(tester, inviteId);
  });
}
