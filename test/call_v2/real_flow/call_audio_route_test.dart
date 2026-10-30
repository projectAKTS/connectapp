import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connect_app/screens/call/agora_call_screen.dart';
import 'package:connect_app/services/call_audio_route.dart';
import 'package:connect_app/services/call_session_manager.dart';
import 'package:connect_app/services/helperly_test_runtime.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// F8: Android audio calls start on the earpiece with the screen off at the
// ear, like WhatsApp; video stays on the speaker.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const callerUid = 'route_caller';
  const calleeUid = 'route_callee';
  late FakeFirebaseFirestore firestore;
  late CallSessionManager manager;

  Future<void> seedConnectedInvite(String inviteId) async {
    await firestore.collection('callInvites').doc(inviteId).set(
      <String, dynamic>{
        'fromUid': callerUid,
        'toUid': calleeUid,
        'fromName': 'Route Caller',
        'toName': 'Route Callee',
        'channel': 'channel_$inviteId',
        'isVideo': false,
        'status': CallInviteStatus.connected.name,
        'callerStage': CallInviteStatus.connected.name,
        'calleeStage': CallInviteStatus.connected.name,
        'createdAt': Timestamp.now(),
      },
    );
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
                      otherUserName: 'Route User',
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
    debugCallEarpieceFirst = true;
    firestore = FakeFirebaseFirestore();
    HelperlyTestRuntime.configureForTest(
      firestore: firestore,
      currentUid: callerUid,
      currentDisplayName: 'Route Caller',
    );
    manager = CallSessionManager.instance;
    await manager.clearForSignedOut();
    await manager.forceIdleForTest();
    HelperlyTestRuntime.configureForTest(
      firestore: firestore,
      currentUid: callerUid,
      currentDisplayName: 'Route Caller',
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
    debugCallEarpieceFirst = null;
  });

  test('audio is earpiece-first only where proximity is handled', () {
    expect(callStartsOnSpeaker(isVideo: false), isFalse);
    expect(callStartsOnSpeaker(isVideo: true), isTrue);
    debugCallEarpieceFirst = false;
    expect(callStartsOnSpeaker(isVideo: false), isTrue);
  });

  testWidgets('an audio call holds proximity only while on the earpiece',
      (tester) async {
    const inviteId = 'route_audio';
    await showConnectedCall(tester, inviteId);
    expect(find.byIcon(Icons.volume_off), findsOne,
        reason: 'the speaker starts off');
    expect(CallProximity.instance.held, isTrue);

    await tester.tap(find.byIcon(Icons.volume_off));
    await tester.pump();
    expect(find.byIcon(Icons.volume_up), findsOne);
    expect(CallProximity.instance.held, isFalse);

    await tester.tap(find.byIcon(Icons.volume_up));
    await tester.pump();
    expect(CallProximity.instance.held, isTrue);

    await closeCall(tester, inviteId);
    expect(CallProximity.instance.held, isFalse);
  });

  testWidgets('a video call stays on the speaker without proximity',
      (tester) async {
    const inviteId = 'route_video';
    await showConnectedCall(tester, inviteId, isVideo: true);
    expect(CallProximity.instance.held, isFalse);
    await closeCall(tester, inviteId);
  });
}
