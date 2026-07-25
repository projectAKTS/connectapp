import 'dart:async';

import '../call_v2_api.dart';
import 'call_v2_rtc_adapter.dart';

enum FakeCallV2RtcAdapterState {
  idle,
  initialized,
  joined,
  active,
  left,
  disposed,
  failed,
}

class FakeCallV2RtcAdapter implements CallV2RtcAdapter {
  FakeCallV2RtcAdapter({
    this.failInitialize = false,
    this.failJoin = false,
  });

  final _events = StreamController<CallV2RtcEvent>.broadcast(sync: true);
  bool failInitialize;
  bool failJoin;
  bool localAudioEnabled = true;
  bool localVideoEnabled = true;
  int initializeCount = 0;
  int joinCount = 0;
  int leaveCount = 0;
  int disposeCount = 0;
  FakeCallV2RtcAdapterState state = FakeCallV2RtcAdapterState.idle;
  CallV2RtcSessionConfig? lastConfig;

  @override
  Stream<CallV2RtcEvent> get events => _events.stream;

  @override
  Future<void> initialize(CallV2RtcSessionConfig config) async {
    initializeCount += 1;
    if (failInitialize) {
      state = FakeCallV2RtcAdapterState.failed;
      _events
          .add(const CallV2RtcFatalError(CallV2RtcErrorCategory.unavailable));
      throw const CallV2ClientError(CallV2ClientErrorCode.unavailable);
    }
    lastConfig = config;
    state = FakeCallV2RtcAdapterState.initialized;
  }

  @override
  Future<void> joinChannel() async {
    joinCount += 1;
    if (state != FakeCallV2RtcAdapterState.initialized || failJoin) {
      state = FakeCallV2RtcAdapterState.failed;
      _events
          .add(const CallV2RtcFatalError(CallV2RtcErrorCategory.unavailable));
      throw const CallV2ClientError(CallV2ClientErrorCode.unavailable);
    }
    _events.add(const CallV2RtcJoinStarted());
    state = FakeCallV2RtcAdapterState.joined;
    _events.add(const CallV2RtcJoined());
  }

  void markActive() {
    if (state == FakeCallV2RtcAdapterState.joined) {
      state = FakeCallV2RtcAdapterState.active;
    }
  }

  @override
  Future<void> leaveChannel() async {
    leaveCount += 1;
    state = FakeCallV2RtcAdapterState.left;
    _events.add(const CallV2RtcRemoteParticipantLeft());
  }

  @override
  Future<void> setMicrophoneEnabled(bool enabled) async {
    localAudioEnabled = enabled;
  }

  @override
  Future<void> setCameraEnabled(bool enabled) async {
    localVideoEnabled = enabled;
  }

  @override
  Future<void> dispose() async {
    disposeCount += 1;
    state = FakeCallV2RtcAdapterState.disposed;
    await _events.close();
  }

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'state': state.name,
      'localAudioEnabled': localAudioEnabled,
      'localVideoEnabled': localVideoEnabled,
      'initializeCount': initializeCount,
      'joinCount': joinCount,
      'leaveCount': leaveCount,
      'disposeCount': disposeCount,
    };
  }
}
