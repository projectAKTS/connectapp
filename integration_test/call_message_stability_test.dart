import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:connect_app/services/call_session_manager.dart';
import 'package:connect_app/services/helperly_test_runtime.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const callerUid = 'helperly_test_caller_uid';
  const calleeUid = 'helperly_test_callee_uid';
  const callerName = 'Test Caller';
  const calleeName = 'Test Callee';
  const cycleCount =
      int.fromEnvironment('HELPERLY_STABILITY_CYCLES', defaultValue: 50);

  late FakeFirebaseFirestore firestore;
  late Map<String, List<Map<String, dynamic>>> chatMessages;
  late Map<String, Map<String, dynamic>> chatDocs;

  Future<void> seedUsers() async {
    await firestore.collection('users').doc(callerUid).set({
      'displayName': callerName,
      'fullName': callerName,
      'diag': {},
    });
    await firestore.collection('users').doc(calleeUid).set({
      'displayName': calleeName,
      'fullName': calleeName,
      'diag': {},
    });
  }

  Future<Map<String, dynamic>> readInvite(String inviteId) async {
    final snap = await firestore.collection('callInvites').doc(inviteId).get();
    return snap.data() ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> waitForTerminalInvite(
    String inviteId, {
    Duration timeout = const Duration(seconds: 3),
    Duration step = const Duration(milliseconds: 50),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      final invite = await readInvite(inviteId);
      final status = '${invite['status'] ?? ''}';
      if (status == 'ended' || status == 'cancelled') {
        return invite;
      }
      await Future<void>.delayed(step);
    }
    final invite = await readInvite(inviteId);
    expect(
      '${invite['status'] ?? ''}',
      anyOf('ended', 'cancelled'),
      reason: 'invite $inviteId did not reach terminal status within $timeout',
    );
    return invite;
  }

  Future<void> simulateChatOpenAndSend({
    required int cycle,
    required String chatId,
  }) async {
    print('[stability-test] chat simulate start $chatId');
    final users = [callerUid, calleeUid]..sort();
    final now = Timestamp.now();
    chatDocs[chatId] = <String, dynamic>{
      ...?chatDocs[chatId],
      'users': users,
      'participants': users,
      'createdAt': now,
      'updatedAt': now,
      'unreadBy': <String, int>{
        callerUid: 0,
        calleeUid: 0,
      },
    };

    print('[stability-test] chat add message');
    final messages =
        chatMessages.putIfAbsent(chatId, () => <Map<String, dynamic>>[]);
    messages.add({
      'id': 'cycle_$cycle',
      'authorId': callerUid,
      'createdAt': now,
      'type': 'text',
      'text': 'cycle-$cycle message',
    });
    print('[stability-test] chat update summary');
    chatDocs[chatId] = <String, dynamic>{
      ...?chatDocs[chatId],
      'users': users,
      'participants': users,
      'updatedAt': now,
      'lastMessageAt': now,
      'lastMessageAuthorId': callerUid,
      'lastMessageType': 'text',
      'lastMessageText': 'cycle-$cycle message',
      'unreadBy': <String, int>{
        callerUid: 0,
        calleeUid: 0,
      },
    };
    expect(messages.length, cycle,
        reason: 'chat message count drifted on cycle $cycle');
    print('[stability-test] chat simulate done');
  }

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    chatMessages = <String, List<Map<String, dynamic>>>{};
    chatDocs = <String, Map<String, dynamic>>{};
    HelperlyTestRuntime.configureForTest(
      firestore: firestore,
      currentUid: callerUid,
      currentDisplayName: callerName,
    );
    await seedUsers();
    CallSessionManager.instance.configure(
      listNativeCalls: () async => const <NativeCallSnapshot>[],
      endNativeCall: (_) async {},
      clearStoredAcceptedCallRecovery: () async {},
    );
    await CallSessionManager.instance.clearForSignedOut();
    HelperlyTestRuntime.configureForTest(
      firestore: firestore,
      currentUid: callerUid,
      currentDisplayName: callerName,
    );
  });

  tearDown(() async {
    await CallSessionManager.instance.clearForSignedOut();
    HelperlyTestRuntime.clear();
  });

  test('outgoing invite creation does not depend on caller profile read',
      () async {
    await firestore.collection('users').doc(callerUid).delete();

    final inviteId = await CallSessionManager.instance.startOutgoingCallForTest(
      toUid: calleeUid,
      toName: calleeName,
      isVideo: true,
    );

    final invite = await readInvite(inviteId);
    expect(invite['status'], 'ringing');
    expect(invite['channel'], isNotEmpty);
    expect(invite['fromName'], callerName);
  });

  test('50 stability cycles stay flat and idle', () async {
    final usedChannels = <String>{};
    Map<String, int>? baselineCounters;

    for (var cycle = 1; cycle <= cycleCount; cycle += 1) {
      print('[stability-test] cycle $cycle/$cycleCount start');
      final isVideo = cycle.isOdd;
      final inviteId =
          await CallSessionManager.instance.startOutgoingCallForTest(
        toUid: calleeUid,
        toName: calleeName,
        isVideo: isVideo,
      );
      final inviteAfterCreate = await readInvite(inviteId);
      print('[stability-test] invite created: $inviteId');
      final channel = '${inviteAfterCreate['channel'] ?? ''}';
      expect(channel, isNotEmpty, reason: 'cycle $cycle missing channel');
      expect(usedChannels.add(channel), isTrue,
          reason: 'cycle $cycle reused channel $channel');
      expect(inviteAfterCreate['status'], 'ringing');

      await firestore.collection('callInvites').doc(inviteId).set({
        'status': 'accepted',
        'acceptedAt': Timestamp.now(),
        'calleeStage': 'accepted',
      }, SetOptions(merge: true));

      await CallSessionManager.instance.reportRemoteJoined(
        inviteId: inviteId,
        isCaller: true,
      );

      final connectedInvite = await readInvite(inviteId);
      print('[stability-test] invite connected: $inviteId');
      expect(connectedInvite['status'], 'connected',
          reason: 'cycle $cycle did not reach connected');

      await CallSessionManager.instance.endCallFromLocalUser(
        inviteId: inviteId,
        source: 'integration_test_end',
      );
      final endedInvite = await waitForTerminalInvite(inviteId);
      expect(
        endedInvite['status'],
        anyOf('ended', 'cancelled'),
        reason: 'cycle $cycle did not reach terminal status',
      );
      await CallSessionManager.instance.forceIdleForTest();
      expect(CallSessionManager.instance.isIdleForDebug, isTrue,
          reason: 'cycle $cycle manager did not reset to idle');
      print('[stability-test] call teardown done: $inviteId');
      final chatId = [callerUid, calleeUid]..sort();
      print('[stability-test] opening chat for cycle $cycle');
      await simulateChatOpenAndSend(
        cycle: cycle,
        chatId: chatId.join('_'),
      );
      print('[stability-test] chat send done for cycle $cycle');

      expect(CallSessionManager.instance.debugLastDiagStage,
          isNot('start_blocked'),
          reason: 'cycle $cycle hit start_blocked');

      final counters = CallSessionManager.instance.debugResourceCounts();
      if (baselineCounters == null) {
        baselineCounters = Map<String, int>.from(counters);
      } else {
        expect(counters, baselineCounters,
            reason: 'cycle $cycle leaked manager counters: $counters');
      }

      expect(CallSessionManager.instance.isIdleForDebug, isTrue,
          reason: 'cycle $cycle manager not idle');
      final snapshot = CallSessionManager.instance.debugSnapshot();
      expect(snapshot['phase'], 'idle');
      expect(snapshot['hasActiveUi'], false);
      expect(snapshot['hasActiveSession'], false);
      print('[stability-test] cycle $cycle/$cycleCount passed');
    }
  });
}
