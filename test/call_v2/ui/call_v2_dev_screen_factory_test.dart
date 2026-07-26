import 'package:connect_app/call_v2/runtime/call_v2_runtime_config.dart';
import 'package:connect_app/call_v2/ui/call_v2_dev_screen.dart';
import 'package:connect_app/call_v2/ui/call_v2_dev_screen_factory.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dev screen factory defaults to fake dev UI', () {
    const factory = CallV2DevScreenFactory();

    final widget = factory.create();
    final debug = factory.describe();

    expect(widget, isA<CallV2DevScreen>());
    expect(debug['fakeDefault'], isTrue);
    expect(debug['rolloutEnabled'], isFalse);
  });

  test('internal dev UI requires explicit internal config', () {
    const factory = CallV2DevScreenFactory();
    const config = CallV2RuntimeConfig.internalRealDevice(
      allowPermissionRequests: true,
      allowTokenRequests: true,
      allowRtcInitialization: true,
      allowRtcJoin: true,
      exposeDevUi: true,
    );

    final widget = factory.create(config: config);
    final debug = factory.describe(config: config);

    expect(widget, isA<CallV2DevScreen>());
    expect(debug['fakeDefault'], isFalse);
    expect(debug['devUiExposed'], isTrue);
    expect(debug['rolloutEnabled'], isFalse);
  });
}
