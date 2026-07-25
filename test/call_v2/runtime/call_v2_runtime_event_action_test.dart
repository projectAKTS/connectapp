import 'package:connect_app/call_v2/runtime/call_v2_runtime_action.dart';
import 'package:connect_app/call_v2/runtime/call_v2_runtime_event.dart';
import 'package:connect_app/call_v2/runtime/call_v2_runtime_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('events cover the required fake runtime lifecycle', () {
    expect(
      CallV2RuntimeEventType.values.map((event) => event.name),
      <String>[
        'startOutgoingCallRequested',
        'permissionPreflightPassed',
        'permissionDenied',
        'fakeRtcConnecting',
        'fakeRtcReady',
        'callActivated',
        'endRequested',
        'ended',
        'failure',
      ],
    );
  });

  test('actions cover the required fake runtime lifecycle', () {
    expect(
      CallV2RuntimeActionType.values.map((action) => action.name),
      <String>[
        'startOutgoingCallRequested',
        'permissionPreflightPassed',
        'permissionDenied',
        'fakeRtcConnecting',
        'fakeRtcReady',
        'callActivated',
        'endRequested',
        'ended',
        'failure',
      ],
    );
  });

  test('event and action debug output is controlled', () {
    const event = CallV2RuntimeEvent.startOutgoingCallRequested(
      mode: CallV2RuntimeCallMode.video,
    );
    const action = CallV2RuntimeAction(CallV2RuntimeActionType.fakeRtcReady);

    expect(event.toSafeDebugMap(), <String, Object?>{
      'type': 'startOutgoingCallRequested',
      'mode': 'video',
      'errorCategory': 'none',
    });
    expect(action.toSafeDebugMap(), <String, Object?>{
      'type': 'fakeRtcReady',
    });
  });
}
