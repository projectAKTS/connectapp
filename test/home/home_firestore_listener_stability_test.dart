import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:connect_app/screens/home/home_content_screen.dart';
import 'package:connect_app/services/diagnostic_service.dart';
import 'package:connect_app/services/helperly_test_runtime.dart';

/// Counts how often Home builds a Firestore query or document stream per
/// collection. Every new stream handed to a `StreamBuilder` is a fresh
/// listener (watch target) on Firestore's single watch stream.
class _CountingFirestore extends FakeFirebaseFirestore {
  final Map<String, int> collectionCalls = <String, int>{};

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    collectionCalls[collectionPath] =
        (collectionCalls[collectionPath] ?? 0) + 1;
    return super.collection(collectionPath);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const uid = 'home_user';
  late _CountingFirestore firestore;
  late StateSetter rebuildParent;

  setUp(() async {
    firestore = _CountingFirestore();
    await firestore.collection('users').doc(uid).set(<String, dynamic>{
      'unreadMessagesCount': 0,
      'connectionsCountSeen': 0,
    });
    firestore.collectionCalls.clear();
    HelperlyTestRuntime.configureForTest(
      firestore: firestore,
      currentUid: uid,
      currentDisplayName: 'Home User',
    );
  });

  tearDown(HelperlyTestRuntime.clear);

  Future<void> pumpHome(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(builder: (context, setState) {
          rebuildParent = setState;
          return ListView(children: <Widget>[
            homeTopBarForTest(currentUid: uid),
            homeWelcomeCardForTest(name: 'Home User'),
          ]);
        }),
      ),
    ));
    await tester.pump();
  }

  Map<String, int> listenerCreations() =>
      Map<String, int>.from(firestore.collectionCalls);

  testWidgets(
      'user document writes and parent rebuilds never re-create Home listeners',
      (tester) async {
    await pumpHome(tester);
    final initial = listenerCreations();
    expect(initial['chats'], 2, reason: 'participants + users queries');
    expect(initial['connections'], 3);
    expect(initial['users'], 2, reason: 'top bar + welcome card user docs');

    // Call setup and teardown write users/{uid} many times in a few seconds
    // (diagnostic stages, token registration, unread counters).
    for (var i = 0; i < 25; i += 1) {
      await firestore.collection('users').doc(uid).set(
          <String, dynamic>{'lastCallStage': 'stage_$i'},
          SetOptions(merge: true));
      await tester.pump();
      if (i.isEven) {
        rebuildParent(() {});
        await tester.pump();
      }
    }

    final users = initial['users']! + 25;
    expect(listenerCreations(), <String, int>{
      'chats': 2,
      'connections': 3,
      // Only the test's own writes; Home created no further user streams.
      'users': users,
    });
  });

  testWidgets('chat and connection updates do not re-create nested listeners',
      (tester) async {
    await pumpHome(tester);
    final initial = listenerCreations();

    for (var i = 0; i < 10; i += 1) {
      await firestore.collection('chats').doc('chat_$i').set(<String, dynamic>{
        'participants': <String>[uid, 'peer_$i'],
        'users': <String>[uid, 'peer_$i'],
        'lastMessageAuthorId': 'peer_$i',
        'unreadBy': <String, int>{uid: 1},
      });
      await firestore
          .collection('connections')
          .doc('connection_$i')
          .set(<String, dynamic>{
        'users': <String>[uid, 'peer_$i'],
        'userId': uid,
        'connectedUserId': 'peer_$i',
      });
      await tester.pump();
    }

    expect(listenerCreations(), <String, int>{
      'chats': initial['chats']! + 10,
      'connections': initial['connections']! + 10,
      'users': initial['users']!,
    });
    // The badges still reflect live data from the single set of listeners.
    expect(find.text('+10'), findsNWidgets(2));
  });

  testWidgets('a new signed-in user id re-creates listeners exactly once',
      (tester) async {
    var currentUid = uid;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(builder: (context, setState) {
          rebuildParent = setState;
          return ListView(children: <Widget>[
            homeTopBarForTest(currentUid: currentUid),
          ]);
        }),
      ),
    ));
    await tester.pump();
    final initial = listenerCreations();

    rebuildParent(() => currentUid = 'other_user');
    await tester.pump();
    rebuildParent(() {});
    await tester.pump();

    expect(listenerCreations(), <String, int>{
      'chats': initial['chats']! + 2,
      'users': initial['users']! + 1,
    });
  });

  test('release diagnostics never write the user document', () async {
    DiagnosticService.logCall('accept_transaction_start', uid: uid);
    DiagnosticService.logPush('callkit_accept', uid: uid);
    DiagnosticService.logSystem('firestore_recover_start');
    DiagnosticService.logLifecycle(AppLifecycleState.resumed);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final user = await firestore.collection('users').doc(uid).get();
    expect(user.data()!.containsKey('diag'), isFalse);
  });
}
