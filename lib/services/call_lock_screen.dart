import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

/// Shows the app over the Android lock screen while an answered call is up,
/// like WhatsApp's in-call screen.
///
/// Behind a PIN keyguard, MainActivity stayed stopped after an answer from
/// the plugin's lock-screen UI: audio connected but the call screen never
/// opened. The flag goes off as soon as the call ends, so the rest of the
/// app stays behind the keyguard. The keyguard itself is never dismissed.
class CallLockScreen {
  CallLockScreen._();

  static final CallLockScreen instance = CallLockScreen._();

  static const MethodChannel _channel =
      MethodChannel('connectapp/callLockScreen');

  bool _shown = false;

  bool get shown => _shown;

  /// Fire-and-forget: call paths never wait on the platform channel.
  void showOverLockScreen(bool show) {
    if (_shown == show) return;
    _shown = show;
    if (!Platform.isAndroid) return;
    unawaited(_channel
        .invokeMethod<void>('setShowOverLockScreen', show)
        .then<void>((_) {}, onError: (Object _) {}));
  }
}
