import 'package:connect_app/services/notification_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  bool ask(
    AuthorizationStatus status, {
    bool foreground = true,
    required bool android,
  }) =>
      NotificationService.shouldRequestNotificationPermission(
        status: status,
        appForeground: foreground,
        isAndroid: android,
      );

  test('Android asks when the grant is missing (reported as denied)', () {
    expect(ask(AuthorizationStatus.denied, android: true), isTrue);
    expect(ask(AuthorizationStatus.notDetermined, android: true), isTrue);
  });

  test('Android does not ask when granted or in the background', () {
    expect(ask(AuthorizationStatus.authorized, android: true), isFalse);
    expect(
      ask(AuthorizationStatus.denied, foreground: false, android: true),
      isFalse,
    );
  });

  test('iOS keeps asking only before the first answer', () {
    expect(ask(AuthorizationStatus.notDetermined, android: false), isTrue);
    expect(ask(AuthorizationStatus.denied, android: false), isFalse);
    expect(ask(AuthorizationStatus.authorized, android: false), isFalse);
    expect(ask(AuthorizationStatus.provisional, android: false), isFalse);
    expect(
      ask(AuthorizationStatus.notDetermined, foreground: false, android: false),
      isFalse,
    );
  });
}
