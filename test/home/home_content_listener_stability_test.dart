import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:connect_app/screens/home/home_content_screen.dart';
import 'package:connect_app/services/helperly_test_runtime.dart';
import 'package:connect_app/widgets/main_scaffold.dart';

/// Counts Firestore stream creations per collection; see
/// home_firestore_listener_stability_test.dart.
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

  setUp(() async {
    firestore = _CountingFirestore();
    await firestore.collection('users').doc(uid).set(<String, dynamic>{
      'displayName': 'Home User',
    });
    for (var i = 0; i < 3; i += 1) {
      await firestore.collection('posts').doc('post_$i').set(<String, dynamic>{
        'userId': 'author_$i',
        'userName': 'Author $i',
        'content': 'Post body $i',
        'timestamp': Timestamp.fromMillisecondsSinceEpoch(1000 + i),
        'likes': 0,
      });
    }
    firestore.collectionCalls.clear();
    HelperlyTestRuntime.configureForTest(
      firestore: firestore,
      currentUid: uid,
      currentDisplayName: 'Home User',
    );
  });

  tearDown(HelperlyTestRuntime.clear);

  testWidgets(
      'post updates and user document writes create no new Home listeners',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: HomeContentScreen(controller: HomeTabController()),
    ));
    for (var i = 0; i < 5; i += 1) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(
        find.textContaining('Post body 0', findRichText: true), findsOneWidget);
    expect(firestore.collectionCalls['posts'], 4,
        reason: 'one posts query plus one listener per visible cell');
    final initial = Map<String, int>.from(firestore.collectionCalls);

    for (var i = 0; i < 10; i += 1) {
      // A like updates the post (posts query + cell emit) and call stages
      // update users/{uid}.
      await firestore
          .collection('posts')
          .doc('post_0')
          .set(<String, dynamic>{'likes': i + 1}, SetOptions(merge: true));
      await firestore.collection('users').doc(uid).set(
          <String, dynamic>{'lastCallStage': 'stage_$i'},
          SetOptions(merge: true));
      await tester.pump(const Duration(milliseconds: 50));
    }

    final after = Map<String, int>.from(firestore.collectionCalls);
    expect(after['posts'], initial['posts']! + 10,
        reason: 'only the test writes; no re-created post listeners');
    expect(after['users'], initial['users']! + 10,
        reason: 'only the test writes; no re-created user listeners');
    expect(after['chats'], initial['chats']);
    expect(after['connections'], initial['connections']);
  });
}
