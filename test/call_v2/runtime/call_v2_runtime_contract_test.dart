import 'package:connect_app/call_v2/runtime/call_v2_runtime.dart';
import 'package:connect_app/call_v2/runtime/call_v2_runtime_state.dart';
import 'package:connect_app/call_v2/runtime/fake_call_v2_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fake runtime satisfies runtime interface', () {
    final runtime = FakeCallV2Runtime();
    addTearDown(runtime.dispose);

    expect(runtime, isA<CallV2Runtime>());
    expect(runtime.currentState, CallV2RuntimeState.idle);
  });
}
