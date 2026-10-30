import 'dart:async';

import 'package:flutter/foundation.dart';

/// What a connected call is currently waiting to recover from.
@immutable
class CallReconnectStatus {
  const CallReconnectStatus({
    required this.inviteId,
    this.localReconnecting = false,
    this.remoteDropped = false,
    this.remoteStalled = false,
  });

  final String inviteId;
  final bool localReconnecting;
  final bool remoteDropped;
  final bool remoteStalled;

  bool get reconnecting => localReconnecting || remoteDropped || remoteStalled;

  CallReconnectStatus copyWith({
    bool? localReconnecting,
    bool? remoteDropped,
    bool? remoteStalled,
  }) {
    return CallReconnectStatus(
      inviteId: inviteId,
      localReconnecting: localReconnecting ?? this.localReconnecting,
      remoteDropped: remoteDropped ?? this.remoteDropped,
      remoteStalled: remoteStalled ?? this.remoteStalled,
    );
  }
}

/// WhatsApp-style recovery for a connected call whose network breaks.
///
/// Agora reports a remote user as dropped after ~20 s without packets. Ending
/// the call right there lost calls that a Wi-Fi reassociation would have
/// recovered: a Samsung phone rejoined 23.4 s after a 5 s Wi-Fi gap, 0.2 s
/// after the other side had hung up.
///
/// - Remote dropped: wait [remoteGrace] for it to rejoin, then end.
/// - Local connection reconnecting: end after [localLimit] without recovery.
/// - Remote audio not arriving for [audioSilenceLimit]: show "Reconnecting…"
///   only. Agora reports the received bitrate every 2 s while audio flows;
///   its frozen/decoding state flipped back to decoding 2 s into an outage.
///
/// The owner (CallSessionManager) checks that the session is still current
/// before acting on an expiry.
class CallReconnectWatch {
  CallReconnectWatch({
    this.remoteGrace = defaultRemoteGrace,
    this.localLimit = defaultLocalLimit,
    this.audioSilenceLimit = defaultAudioSilenceLimit,
  });

  static const Duration defaultRemoteGrace = Duration(seconds: 25);
  static const Duration defaultLocalLimit = Duration(seconds: 45);
  static const Duration defaultAudioSilenceLimit = Duration(milliseconds: 3500);

  /// Agora's `userOfflineDropped`, as opposed to a hang-up (`userOfflineQuit`).
  static bool isNetworkDrop(String reason) =>
      reason.toLowerCase().contains('dropped');

  final Duration remoteGrace;
  final Duration localLimit;
  final Duration audioSilenceLimit;

  final ValueNotifier<CallReconnectStatus?> status =
      ValueNotifier<CallReconnectStatus?>(null);

  Timer? _remoteTimer;
  Timer? _localTimer;
  Timer? _stallTimer;
  bool _remoteMuted = false;

  void remoteDropped(String inviteId, {required VoidCallback onExpired}) {
    _switchTo(inviteId);
    if (_remoteTimer != null) return;
    _stallTimer?.cancel();
    _stallTimer = null;
    _remoteTimer = Timer(remoteGrace, () {
      _remoteTimer = null;
      onExpired();
    });
    _update(remoteDropped: true, remoteStalled: false);
  }

  void remoteRejoined(String inviteId) {
    if (!_isCurrent(inviteId)) return;
    _remoteTimer?.cancel();
    _remoteTimer = null;
    _stallTimer?.cancel();
    _stallTimer = null;
    _update(remoteDropped: false, remoteStalled: false);
  }

  void localReconnecting(
    String inviteId,
    bool reconnecting, {
    required VoidCallback onLimit,
  }) {
    if (!reconnecting) {
      if (!_isCurrent(inviteId)) return;
      _localTimer?.cancel();
      _localTimer = null;
      _update(localReconnecting: false);
      return;
    }
    _switchTo(inviteId);
    if (_localTimer != null) return;
    _localTimer = Timer(localLimit, () {
      _localTimer = null;
      onLimit();
    });
    _update(localReconnecting: true);
  }

  /// One `onRemoteAudioStats` report. A positive bitrate means audio is
  /// flowing; nothing is armed until the first one.
  void remoteAudioReport(String inviteId, int receivedBitrate) {
    if (receivedBitrate <= 0) return;
    _switchTo(inviteId);
    if (_remoteMuted) return;
    _armSilence();
    if (status.value!.remoteStalled) _update(remoteStalled: false);
  }

  /// A muted remote sends no audio, which is not a network problem. Before
  /// any audio has flowed there is nothing to stop.
  void remoteAudioMuted(String inviteId, bool muted) {
    if (!_isCurrent(inviteId)) return;
    _remoteMuted = muted;
    if (!muted) return;
    _stallTimer?.cancel();
    _stallTimer = null;
    _update(remoteStalled: false);
  }

  void _armSilence() {
    _stallTimer?.cancel();
    _stallTimer = Timer(audioSilenceLimit, () {
      _stallTimer = null;
      _update(remoteStalled: true);
    });
  }

  void reset() {
    _remoteTimer?.cancel();
    _localTimer?.cancel();
    _stallTimer?.cancel();
    _remoteTimer = null;
    _localTimer = null;
    _stallTimer = null;
    _remoteMuted = false;
    status.value = null;
  }

  bool _isCurrent(String inviteId) => status.value?.inviteId == inviteId;

  void _switchTo(String inviteId) {
    if (_isCurrent(inviteId)) return;
    reset();
    status.value = CallReconnectStatus(inviteId: inviteId);
  }

  void _update({
    bool? localReconnecting,
    bool? remoteDropped,
    bool? remoteStalled,
  }) {
    final current = status.value;
    if (current == null) return;
    status.value = current.copyWith(
      localReconnecting: localReconnecting,
      remoteDropped: remoteDropped,
      remoteStalled: remoteStalled,
    );
  }
}
