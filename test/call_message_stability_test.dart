// Needs the app's test mode: run with
//   flutter test --tags test-mode --dart-define=HELPERLY_TEST_MODE=true
// CI runs it in its own step (see docs/TESTING.md).
@Tags(['test-mode'])
library;

import 'package:flutter_test/flutter_test.dart';

import '../integration_test/call_message_stability_test.dart' as stability;

void main() {
  stability.main();
}
