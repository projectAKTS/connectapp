import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:connect_app/utils/time_utils.dart';

void main() {
  test('a seen time still being written counts as now, not never', () {
    final before = DateTime.now();
    final pending = seenTimestamp({'lastMessagesSeenAt': null}, 'lastMessagesSeenAt');
    expect(pending, isNotNull);
    expect(pending!.isBefore(before), isFalse);
  });

  test('never seen and a stored time read as they are', () {
    expect(seenTimestamp({}, 'lastMessagesSeenAt'), isNull);
    expect(seenTimestamp(null, 'lastMessagesSeenAt'), isNull);
    final at = DateTime.utc(2026, 11, 1);
    expect(
      seenTimestamp({'k': Timestamp.fromDate(at)}, 'k')!.toUtc(),
      at,
    );
  });
}
