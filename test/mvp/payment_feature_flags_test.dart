import 'package:connect_app/config/mvp_features.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('default production configuration keeps every payment surface off', () {
    expect(MvpFeatures.paymentsEnabled, isFalse);
    expect(MvpFeatures.paidSessions, isFalse);
    expect(MvpFeatures.subscriptionsEnabled, isFalse);
    expect(MvpFeatures.premium, isFalse);
  });
}
