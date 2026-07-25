import 'package:flutter/material.dart';

import '../runtime/call_v2_runtime_state.dart';
import '../runtime/fake_call_v2_runtime.dart';

class CallV2DevScreen extends StatefulWidget {
  const CallV2DevScreen({
    super.key,
    this.runtime,
  });

  final FakeCallV2Runtime? runtime;

  @override
  State<CallV2DevScreen> createState() => _CallV2DevScreenState();
}

class _CallV2DevScreenState extends State<CallV2DevScreen> {
  late final FakeCallV2Runtime _runtime = widget.runtime ?? FakeCallV2Runtime();
  late final bool _ownsRuntime = widget.runtime == null;

  @override
  void dispose() {
    if (_ownsRuntime) {
      _runtime.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _runtime,
      builder: (context, _) {
        final state = _runtime.currentState;
        return Scaffold(
          appBar: AppBar(title: const Text('Call V2 Dev')),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  _labelFor(state),
                  key: const ValueKey<String>('call-v2-dev-state'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  key: const ValueKey<String>('start-audio'),
                  onPressed: () => _runtime.startOutgoingCall(
                    mode: CallV2RuntimeCallMode.audio,
                  ),
                  child: const Text('Start audio'),
                ),
                FilledButton(
                  key: const ValueKey<String>('start-video'),
                  onPressed: () => _runtime.startOutgoingCall(
                    mode: CallV2RuntimeCallMode.video,
                  ),
                  child: const Text('Start video'),
                ),
                FilledButton(
                  key: const ValueKey<String>('request-permission'),
                  onPressed:
                      state.phase == CallV2RuntimePhase.permissionPreflight
                          ? _runtime.requestRequiredPermissions
                          : null,
                  child: const Text('Request permissions'),
                ),
                FilledButton(
                  key: const ValueKey<String>('connect-fake-rtc'),
                  onPressed: state.phase == CallV2RuntimePhase.connecting
                      ? _runtime.connectFakeRtc
                      : null,
                  child: const Text('Connect fake RTC'),
                ),
                FilledButton(
                  key: const ValueKey<String>('activate-call'),
                  onPressed: state.phase == CallV2RuntimePhase.ready
                      ? _runtime.activateCall
                      : null,
                  child: const Text('Activate'),
                ),
                OutlinedButton(
                  key: const ValueKey<String>('end-call'),
                  onPressed: state.phase == CallV2RuntimePhase.idle
                      ? null
                      : _runtime.endCall,
                  child: const Text('End'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

String _labelFor(CallV2RuntimeState state) {
  switch (state.phase) {
    case CallV2RuntimePhase.idle:
      return 'Idle';
    case CallV2RuntimePhase.preparing:
      return 'Preparing';
    case CallV2RuntimePhase.permissionPreflight:
      return 'Permission preflight';
    case CallV2RuntimePhase.requestingPermission:
      return 'Requesting permission';
    case CallV2RuntimePhase.connecting:
      return 'Connecting';
    case CallV2RuntimePhase.ringing:
      return 'Ringing';
    case CallV2RuntimePhase.ready:
      return 'Ready';
    case CallV2RuntimePhase.active:
      return 'Active';
    case CallV2RuntimePhase.ending:
      return 'Ending';
    case CallV2RuntimePhase.ended:
      return 'Ended';
    case CallV2RuntimePhase.failed:
      return 'Failed';
  }
}
