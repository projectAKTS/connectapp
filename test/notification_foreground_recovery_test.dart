import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:connect_app/services/call_session_manager.dart';
import 'package:connect_app/services/helperly_test_runtime.dart';
import 'package:connect_app/services/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const callerUid = 'helperly_test_caller_uid';
  const calleeUid = 'helperly_test_callee_uid';
  const callerName = 'Test Caller';
  const calleeName = 'Test Callee';

  late FakeFirebaseFirestore firestore;
  late NotificationService notificationService;
  late GlobalKey<NavigatorState> navigatorKey;

  Future<void> seedUsers() async {
    await firestore.collection('users').doc(callerUid).set({
      'displayName': callerName,
      'fullName': callerName,
      'diag': <String, dynamic>{},
    });
    await firestore.collection('users').doc(calleeUid).set({
      'displayName': calleeName,
      'fullName': calleeName,
      'diag': <String, dynamic>{},
    });
  }

  Widget buildHarness() {
    return MaterialApp(
      navigatorKey: navigatorKey,
      home: const Scaffold(body: Text('home')),
      onGenerateRoute: (settings) {
        if (settings.name != '/chat') return null;
        final args = settings.arguments as Map<String, dynamic>? ??
            const <String, dynamic>{};
        final otherUserId = (args['otherUserId'] ?? '').toString();
        final chatId = (args['chatId'] ?? '').toString();
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => Scaffold(
            body: Text('chat:$otherUserId:$chatId'),
          ),
        );
      },
    );
  }

  setUp(() async {
    setupFirebaseCoreMocks();
    try {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: 'test',
          appId: '1:123:ios:test',
          messagingSenderId: '123',
          projectId: 'helperly-test',
        ),
      );
    } catch (_) {}
    firestore = FakeFirebaseFirestore();
    navigatorKey = GlobalKey<NavigatorState>();
    HelperlyTestRuntime.configureForTest(
      firestore: firestore,
      currentUid: calleeUid,
      currentDisplayName: calleeName,
    );
    await seedUsers();
    notificationService = NotificationService(navigatorKey: navigatorKey);
    await CallSessionManager.instance.clearForSignedOut();
    HelperlyTestRuntime.configureForTest(
      firestore: firestore,
      currentUid: calleeUid,
      currentDisplayName: calleeName,
    );
  });

  tearDown(() async {
    await notificationService.dispose();
    await CallSessionManager.instance.clearForSignedOut();
    HelperlyTestRuntime.clear();
  });

  testWidgets(
    'foreground voip handoff while paused eventually opens the in-app incoming prompt',
    (tester) async {
      final inviteId = 'invite_foreground_retry';
      const channel = 'c_test_foreground_retry';

      await firestore.collection('callInvites').doc(inviteId).set({
        'fromUid': callerUid,
        'fromName': callerName,
        'toUid': calleeUid,
        'toName': calleeName,
        'channel': channel,
        'isVideo': false,
        'status': 'ringing',
        'createdAt': Timestamp.now(),
        'callerStage': 'ringing',
        'calleeStage': 'idle',
      });

      await tester.pumpWidget(buildHarness());
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();

      unawaited(
        notificationService.debugSimulateForegroundVoipForTest(
          inviteId: inviteId,
          channel: channel,
          fromName: callerName,
          fromUid: callerUid,
          isVideo: false,
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Incoming Audio Call'), findsNothing);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      expect(find.text('Incoming Audio Call'), findsOneWidget);
      expect(find.text(callerName), findsOneWidget);
      expect(find.text('Accept'), findsOneWidget);
      expect(find.text('Decline'), findsOneWidget);
    },
  );

  test('safe push diagnostics strip CallKit and identifier fields', () {
    final safe = notificationService.debugSafePushDiagMetaForTest(
      const <String, dynamic>{
        'callkitId': 'unsafe-native-id',
        'inviteId': 'unsafe-invite-id',
        'channel': 'unsafe-channel',
        'uid': 'unsafe-user',
        'safeFlag': true,
      },
    );
    final text = safe.toString().toLowerCase();

    expect(text, isNot(contains('callkitid')));
    expect(text, isNot(contains('unsafe-native-id')));
    expect(text, isNot(contains('inviteid')));
    expect(text, isNot(contains('unsafe-invite-id')));
    expect(text, isNot(contains('unsafe-channel')));
    expect(text, isNot(contains('unsafe-user')));
    expect(safe['identifierFieldPresent'], isTrue);
    expect(safe['safeFlag'], isTrue);
  });

  testWidgets(
    'chat tap while paused reopens the correct chat instead of leaving a stale one',
    (tester) async {
      final expectedChatId = ([callerUid, calleeUid]..sort()).join('_');
      await tester.pumpWidget(buildHarness());
      navigatorKey.currentState!.pushNamed(
        '/chat',
        arguments: const <String, dynamic>{
          'otherUserId': 'old_user',
          'chatId': 'old_chat',
        },
      );
      await tester.pumpAndSettle();
      expect(find.text('chat:old_user:old_chat'), findsOneWidget);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();

      unawaited(
        notificationService.debugOpenChatFromTapForTest(
          otherUserId: callerUid,
          chatId: expectedChatId,
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('chat:old_user:old_chat'), findsOneWidget);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      expect(find.text('chat:$callerUid:$expectedChatId'), findsOneWidget);
      expect(find.text('chat:old_user:old_chat'), findsNothing);
    },
  );
}
