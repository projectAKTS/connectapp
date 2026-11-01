import 'package:connect_app/services/android_incoming_call.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 10, 31, 12);
  Map<String, dynamic> invite({String isVideo = 'false', String from = ''}) => {
        'type': 'call_invite',
        'callId': 'inviteLang1',
        'channel': 'c_lang',
        'isVideo': isVideo,
        'fromName': from,
        'fromUid': 'caller',
        'toUid': 'callee',
      };

  test('the full-screen call UI follows the device language', () {
    final fr =
        AndroidIncomingCall.decide(invite(), now: now, languageCode: 'fr')
            .params!;
    expect(fr.textAccept, 'Accepter');
    expect(fr.textDecline, 'Refuser');
    expect(fr.handle, 'Appel audio');
    expect(fr.nameCaller, 'Appelant');

    final frVideo = AndroidIncomingCall.decide(invite(isVideo: 'true'),
            now: now, languageCode: 'fr')
        .params!;
    expect(frVideo.handle, 'Appel vidéo');
  });

  test('other device languages get the unchanged English texts', () {
    for (final code in ['en', 'tr', 'ar']) {
      final p = AndroidIncomingCall.decide(invite(from: 'Baris'),
              now: now, languageCode: code)
          .params!;
      expect(p.textAccept, 'Accept');
      expect(p.textDecline, 'Decline');
      expect(p.handle, 'Audio call');
      expect(p.nameCaller, 'Baris');
    }
  });
}
