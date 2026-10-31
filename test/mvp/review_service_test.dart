import 'package:connect_app/services/helperly_test_runtime.dart';
import 'package:connect_app/services/review_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  final reviews = ReviewService.instance;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    HelperlyTestRuntime.configureForTest(
      firestore: firestore,
      currentUid: 'me',
    );
  });

  tearDown(HelperlyTestRuntime.clear);

  test('a review is keyed by the consultation and names both sides', () async {
    await reviews.submit(
      consultationId: 'c1',
      helperUid: 'helper',
      stars: 4,
      text: '  Great resume tips.  ',
    );
    final doc = await firestore.collection('reviews').doc('c1').get();
    final data = doc.data()!;
    expect(data['consultationId'], 'c1');
    expect(data['reviewerUid'], 'me');
    expect(data['helperUid'], 'helper');
    expect(data['stars'], 4);
    expect(data['text'], 'Great resume tips.');
    expect(data.keys.toSet(), {
      'consultationId',
      'reviewerUid',
      'helperUid',
      'stars',
      'text',
      'createdAt',
    });
  });

  test('reviewed ids are the signed-in user\'s own', () async {
    await firestore
        .collection('reviews')
        .doc('mine')
        .set({'reviewerUid': 'me', 'helperUid': 'h'});
    await firestore
        .collection('reviews')
        .doc('theirs')
        .set({'reviewerUid': 'other', 'helperUid': 'h'});
    expect(await reviews.reviewedConsultationIds().first, {'mine'});
  });

  testWidgets('the sheet needs stars and filters the comment', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Builder(builder: (c) {
        ctx = c;
        return const SizedBox();
      })),
    ));
    final saved = reviews.rateWithSheet(
      ctx,
      consultationId: 'c2',
      helperUid: 'helper',
      helperName: 'Sam',
    );
    await tester.pumpAndSettle();
    expect(find.text('How was your session with Sam?'), findsOneWidget);

    final submit = find.byKey(const Key('rate_submit'));
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);

    await tester.tap(find.byKey(const Key('rate_star_5')));
    await tester.enterText(find.byType(TextField), 'send me porn');
    await tester.pump();
    await tester.tap(submit);
    await tester.pump();
    expect(find.textContaining('Community guidelines'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Very kind and clear.');
    await tester.pump();
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(await saved, isTrue);

    final data = (await firestore.collection('reviews').doc('c2').get()).data();
    expect(data?['stars'], 5);
    expect(data?['text'], 'Very kind and clear.');
  });
}
