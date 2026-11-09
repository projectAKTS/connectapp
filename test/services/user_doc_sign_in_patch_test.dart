import 'package:flutter_test/flutter_test.dart';

import 'package:connect_app/services/user_doc_sign_in_patch.dart';

void main() {
  Map<String, dynamic> patch({
    bool exists = true,
    bool fromServer = true,
    Map<String, dynamic> data = const {},
    String authName = '',
  }) =>
      userDocSignInPatch(
        exists: exists,
        fromServer: fromServer,
        data: data,
        authName: authName,
        appLocale: 'fr',
      );

  test('a cached read writes only the locale, never a name', () {
    // A fresh install's cache holds only the push-token write: no name.
    expect(patch(fromServer: false, data: {'fcmToken': 'x'}),
        {'appLocale': 'fr'});
    expect(patch(fromServer: false, exists: false), {'appLocale': 'fr'});
  });

  test('a server read keeps the existing name and adds no defaults', () {
    final p = patch(data: {'displayName': 'Amira', 'bio': 'hi'});
    expect(p['displayName'], 'Amira');
    expect(p['fullNameLower'], 'amira');
    expect(p.containsKey('bio'), isFalse);
    expect(p.containsKey('followers'), isFalse);
  });

  test('a missing profile on the server gets a name and the defaults', () {
    final p = patch(exists: false, authName: ' Sam ');
    expect(p['fullName'], 'Sam');
    expect(p['bio'], '');
    expect(p['followers'], isEmpty);
    expect(patch(exists: false)['displayName'], 'User');
  });
}
