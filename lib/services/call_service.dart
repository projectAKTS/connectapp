import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:connect_app/call_v2/real_flow/call_v2_real_call_flow_gate.dart';
import 'package:connect_app/services/call_session_manager.dart';
import 'package:connect_app/services/helperly_test_runtime.dart';

typedef CallServiceCurrentUidProvider = String? Function();

typedef CallServiceStartSession = Future<bool> Function(
  BuildContext context, {
  required String toUid,
  required String toName,
  required bool isVideo,
  required CallV2RealCallFlowDecision callV2Decision,
});

class CallService {
  const CallService({
    this.callV2Gate = const CallV2RealCallFlowGate(),
    this.currentUidProvider,
    this.startSession,
  });

  final CallV2RealCallFlowGate callV2Gate;
  final CallServiceCurrentUidProvider? currentUidProvider;
  final CallServiceStartSession? startSession;

  static String generateChannelName(String uid1, String uid2) {
    return CallSessionManager.generateChannelName(uid1, uid2);
  }

  Future<void> startCall(
    BuildContext context, {
    required String toUid,
    required String toName,
    required bool isVideo,
    bool navigateCaller = true,
  }) async {
    final me = (currentUidProvider?.call() ??
            HelperlyTestRuntime.currentUid ??
            FirebaseAuth.instance.currentUser?.uid)
        ?.trim();
    if (me == null || me.isEmpty) throw Exception('Not signed in');

    if (navigateCaller) {
      if (!context.mounted) return;
      final decision = callV2Gate.selectForUserStartedCall(isVideo: isVideo);
      final starter = startSession ?? _defaultStartSession;
      await starter(
        context,
        toUid: toUid,
        toName: toName,
        isVideo: isVideo,
        callV2Decision: decision,
      );
    }
  }

  static Future<bool> _defaultStartSession(
    BuildContext context, {
    required String toUid,
    required String toName,
    required bool isVideo,
    required CallV2RealCallFlowDecision callV2Decision,
  }) {
    return CallSessionManager.instance.startOutgoingCall(
      context,
      toUid: toUid,
      toName: toName,
      isVideo: isVideo,
      callV2Decision: callV2Decision,
    );
  }
}
