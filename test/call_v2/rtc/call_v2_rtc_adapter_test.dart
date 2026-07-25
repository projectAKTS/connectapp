import 'package:connect_app/call_v2/call_v2_api.dart';
import 'package:connect_app/call_v2/rtc/call_v2_rtc_adapter.dart';
import 'package:connect_app/call_v2/rtc/fake_call_v2_rtc_adapter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fake RTC adapter simulates initialize, join, active, leave', () async {
    final adapter = FakeCallV2RtcAdapter();
    addTearDown(adapter.dispose);

    await adapter.initialize(_config());
    await adapter.joinChannel();
    adapter.markActive();
    await adapter.setMicrophoneEnabled(false);
    await adapter.setCameraEnabled(false);
    await adapter.leaveChannel();

    expect(adapter.initializeCount, 1);
    expect(adapter.joinCount, 1);
    expect(adapter.leaveCount, 1);
    expect(adapter.localAudioEnabled, isFalse);
    expect(adapter.localVideoEnabled, isFalse);
    expect(adapter.state, FakeCallV2RtcAdapterState.left);
  });

  test('fake RTC adapter supports controlled failure', () async {
    final adapter = FakeCallV2RtcAdapter(failInitialize: true);
    addTearDown(adapter.dispose);

    await expectLater(
      adapter.initialize(_config()),
      throwsA(isA<CallV2ClientError>()),
    );
    expect(adapter.state, FakeCallV2RtcAdapterState.failed);
  });
}

CallV2RtcSessionConfig _config() {
  return const CallV2RtcSessionConfig(
    callId: 'fake-call',
    channelName: 'fake-channel',
    rtcUid: 42,
    isVideo: true,
    token: 'fake-token',
  );
}
