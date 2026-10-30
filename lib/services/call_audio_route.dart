import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

bool? _debugEarpieceFirst;

/// Overrides the platform choice in tests; null restores it.
@visibleForTesting
set debugCallEarpieceFirst(bool? value) => _debugEarpieceFirst = value;

/// WhatsApp-like routing: video calls start on the speaker, audio calls on
/// the earpiece. Only Android audio is earpiece-first for now: iOS needs its
/// own proximity monitoring and a device run before it changes.
bool callStartsOnSpeaker({required bool isVideo}) {
  if (isVideo) return true;
  return !(_debugEarpieceFirst ?? Platform.isAndroid);
}

/// Turns the screen off at the ear while an audio call is on the earpiece,
/// so a cheek cannot tap hang-up or mute.
class CallProximity {
  CallProximity._();

  static final CallProximity instance = CallProximity._();

  static const MethodChannel _channel =
      MethodChannel('connectapp/callProximity');

  bool _held = false;

  bool get held => _held;

  /// Fire-and-forget: call paths never wait on the platform channel.
  void hold(bool held) {
    if (_held == held) return;
    _held = held;
    if (!Platform.isAndroid) return;
    unawaited(_channel
        .invokeMethod<void>('setProximityScreenOff', held)
        .then<void>((_) {}, onError: (Object _) {}));
  }
}
