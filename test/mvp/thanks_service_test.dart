import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connect_app/services/helperly_test_runtime.dart';
import 'package:connect_app/services/thanks_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  final thanks = ThanksService.instance;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    HelperlyTestRuntime.configureForTest(firestore: firestore, currentUid: 'me');
  });

  tearDown(HelperlyTestRuntime.clear);

  test('a note is keyed by chat and sender, with only the allowed fields',
      () async {
    await thanks.send(chatId: 'me_bob', toUid: 'bob', text: '  Thank you!  ');
    final doc = await firestore.collection('thanks').doc('me_bob_me').get();
    expect(doc.data()!['text'], 'Thank you!');
    expect(doc.data()!['fromUid'], 'me');
    expect(doc.data()!['toUid'], 'bob');
    expect(doc.data()!.keys.toSet(),
        {'chatId', 'fromUid', 'toUid', 'text', 'createdAt'});
    expect(await thanks.hasThanked('me_bob'), isTrue);
    expect(await thanks.hasThanked('me_carol'), isFalse);
  });

  test('notes to a person come newest first', () async {
    final col = firestore.collection('thanks');
    await col.doc('a').set({
      'toUid': 'bob',
      'text': 'old',
      'createdAt': Timestamp.fromMillisecondsSinceEpoch(1000),
    });
    await col.doc('b').set({
      'toUid': 'bob',
      'text': 'new',
      'createdAt': Timestamp.fromMillisecondsSinceEpoch(2000),
    });
    await col.doc('c').set({'toUid': 'other', 'text': 'x'});
    final notes = await thanks.notesTo('bob').first;
    expect(notes.map((e) => e.key), ['b', 'a']);
  });

  testWidgets('the sheet needs text, filters it, then saves', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Builder(builder: (c) {
        ctx = c;
        return const SizedBox();
      })),
    ));
    final saved = thanks.thankWithSheet(ctx,
        chatId: 'me_sam', toUid: 'sam', toName: 'Sam');
    await tester.pumpAndSettle();
    expect(find.text('Thank Sam'), findsOneWidget);

    final submit = find.byKey(const Key('thanks_submit'));
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'send me porn');
    await tester.pump();
    await tester.tap(submit);
    await tester.pump();
    expect(find.byType(TextField), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'You saved my week.');
    await tester.pump();
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(await saved, isTrue);
    final doc = await firestore.collection('thanks').doc('me_sam_me').get();
    expect(doc.data()!['text'], 'You saved my week.');
  });
}
