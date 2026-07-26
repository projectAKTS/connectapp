import 'package:connect_app/call_v2/runtime/call_v2_dev_runtime_config_source.dart';
import 'package:connect_app/call_v2/runtime/call_v2_manual_session_inputs.dart';
import 'package:connect_app/call_v2/runtime/call_v2_runtime_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('builds config and reports missing app id as blocked', () {
    final source = CallV2DevRuntimeConfigSource(_inputs(app: ''));

    expect(source.blocksRtcSetup, isTrue);
    expect(source.buildConfig().allowRtcInitialization, isFalse);
    expect(source.toString(), isNot(contains('session_a')));
    expect(source.toString(), isNot(contains('app-for-test')));
  });
}

CallV2ManualSessionInputs _inputs({required String app}) {
  return CallV2ManualSessionInputs(
    rtcApplicationIdentifier: app,
    sessionIdentifier: 'session_a',
    localParticipantIdentifier: 'local_a',
    remoteParticipantIdentifier: 'remote_b',
    mode: CallV2RuntimeCallMode.audio,
    useRealAdapters: true,
    allowPermissionRequests: true,
    allowTokenRequests: true,
    allowRtcInitialization: true,
    allowRtcJoin: true,
  );
}
