import 'package:connect_app/services/helperly_test_runtime.dart';
import 'package:connect_app/services/safety_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  final safety = SafetyService.instance;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    HelperlyTestRuntime.configureForTest(
      firestore: firestore,
      currentUid: 'me',
    );
    safety.stop();
  });

  tearDown(() {
    safety.stop();
    HelperlyTestRuntime.clear();
  });

  test('a report records who reported what and why', () async {
    await safety.report(
      type: 'post',
      targetId: 'post_1',
      targetUid: 'author',
      reason: 'Spam or scam',
    );
    final docs = (await firestore.collection('reports').get()).docs;
    expect(docs, hasLength(1));
    final data = docs.single.data();
    expect(data['type'], 'post');
    expect(data['targetId'], 'post_1');
    expect(data['targetUid'], 'author');
    expect(data['reporterUid'], 'me');
    expect(data['reason'], 'Spam or scam');
    expect(data['status'], 'open');
  });

  test('block and unblock update the own user doc and the local set',
      () async {
    await safety.setBlocked('spammer', true);
    expect(safety.isBlocked('spammer'), isTrue);
    var me = (await firestore.collection('users').doc('me').get()).data()!;
    expect(me['blockedUids'], ['spammer']);

    await safety.setBlocked('spammer', false);
    expect(safety.isBlocked('spammer'), isFalse);
    me = (await firestore.collection('users').doc('me').get()).data()!;
    expect(me['blockedUids'], isEmpty);
  });

  test('blocking yourself is ignored', () async {
    await safety.setBlocked('me', true);
    expect(safety.isBlocked('me'), isFalse);
    expect((await firestore.collection('users').doc('me').get()).exists,
        isFalse);
  });

  test('watch picks up blocks made on another device', () async {
    safety.watch();
    await firestore.collection('users').doc('me').set({
      'blockedUids': ['troll'],
    });
    await Future<void>.delayed(Duration.zero);
    expect(safety.isBlocked('troll'), isTrue);
  });
}
