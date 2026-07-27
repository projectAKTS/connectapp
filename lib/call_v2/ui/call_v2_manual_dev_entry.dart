import 'package:flutter/material.dart';

import '../firebase/call_v2_callable_transport.dart';
import '../firebase/call_v2_dev_callable_target.dart';
import '../permissions/real_call_v2_permission_adapter.dart';
import '../rtc/agora_call_v2_rtc_adapter.dart';
import 'call_v2_dev_screen_factory.dart';
import 'call_v2_manual_dev_form.dart';

enum CallV2ManualDevMode {
  fake,
  internalFakeAdapters,
  internalRealAdapters,
}

class CallV2ManualDevEntry extends StatelessWidget {
  const CallV2ManualDevEntry({
    super.key,
    this.screenFactory = const CallV2DevScreenFactory(),
    this.callableTransport,
    this.devCallableTarget = const FirebaseCallV2DevCallableTarget(),
    this.permissionClient,
    this.rtcClient,
  });

  final CallV2DevScreenFactory screenFactory;
  final CallV2CallableTransport? callableTransport;
  final CallV2DevCallableTarget devCallableTarget;
  final RealCallV2PermissionClient? permissionClient;
  final AgoraCallV2RtcEngineClient? rtcClient;

  @override
  Widget build(BuildContext context) {
    return CallV2ManualDevForm(
      screenFactory: screenFactory,
      callableTransport: callableTransport,
      devCallableTarget: devCallableTarget,
      permissionClient: permissionClient,
      rtcClient: rtcClient,
    );
  }
}
