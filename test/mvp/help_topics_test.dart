import 'package:connect_app/models/help_topics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a seeker topic finds helpers with related expertise', () {
    expect(
      HelpTopics.helperFitsTopic(
          topic: 'Job hunting', expertiseTags: ['Resume review']),
      isTrue,
    );
    expect(
      HelpTopics.helperFitsTopic(
          topic: 'Housing', expertiseTags: ['Housing search']),
      isTrue,
    );
    expect(
      HelpTopics.helperFitsTopic(
          topic: 'Job hunting', expertiseTags: ['Language practice']),
      isFalse,
    );
  });

  test('older profiles that stored topics directly still match', () {
    expect(
      HelpTopics.helperFitsTopic(
        topic: 'Parenting support',
        expertiseTags: const [],
        legacyTags: ['Parenting support'],
      ),
      isTrue,
    );
  });

  test('every topic has at least one expertise that answers it', () {
    for (final topic in HelpTopics.topics) {
      final answered = HelpTopics.expertise.any(
          (e) => HelpTopics.helperFitsTopic(topic: topic, expertiseTags: [e]));
      expect(answered, isTrue, reason: topic);
    }
  });
}
