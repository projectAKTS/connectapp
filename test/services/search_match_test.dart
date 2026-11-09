import 'package:flutter_test/flutter_test.dart';

import 'package:connect_app/services/search_match.dart';

void main() {
  String norm(String s) => s.toLowerCase();

  int score(String q, String name, [List<String> fields = const []]) =>
      searchScore(query: q, name: name, fields: fields, normalize: norm);

  test('every word must appear, in any order and any field', () {
    expect(score('housing montreal', 'Amira', ['Housing search', 'Montreal']),
        greaterThan(0));
    expect(score('montreal housing', 'Amira', ['Housing search', 'Montreal']),
        greaterThan(0));
    expect(score('housing toronto', 'Amira', ['Housing search', 'Montreal']),
        0);
  });

  test('name matches rank above matches elsewhere', () {
    expect(score('ami', 'Amira Benali'), 3);
    expect(score('ben', 'Amira Benali'), 3);
    expect(score('benali amira', 'Amira Benali'), 2);
    expect(score('housing', 'Amira', ['Housing search']), 1);
  });

  test('expanded terms match a topic named in another language', () {
    expect(
      searchScore(
        query: 'logement',
        name: 'Sam',
        fields: ['Housing'],
        normalize: norm,
        expand: (w) => w == 'logement' ? {'logement', 'housing'} : {w},
      ),
      1,
    );
  });

  test('an empty query matches nothing', () {
    expect(score('  ', 'Anyone'), 0);
  });
}
