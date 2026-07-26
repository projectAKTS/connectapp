import 'package:flutter/material.dart';

import '../runtime/call_v2_runtime.dart';
import '../runtime/call_v2_runtime_state.dart';
import '../runtime/fake_call_v2_runtime.dart';
import '../runtime/internal_call_v2_runtime.dart';

class CallV2DevScreen extends StatefulWidget {
  const CallV2DevScreen({
    super.key,
    this.runtime,
  });

  final CallV2Runtime? runtime;

  @override
  State<CallV2DevScreen> createState() => _CallV2DevScreenState();
}

class _CallV2DevScreenState extends State<CallV2DevScreen> {
  late final CallV2Runtime _runtime = widget.runtime ?? FakeCallV2Runtime();
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
                          ? _requestPermissions
                          : null,
                  child: const Text('Request permissions'),
                ),
                FilledButton(
                  key: const ValueKey<String>('connect-fake-rtc'),
                  onPressed: state.phase == CallV2RuntimePhase.connecting
                      ? _connectFakeRtc
                      : null,
                  child: const Text('Connect fake RTC'),
                ),
                FilledButton(
                  key: const ValueKey<String>('request-internal-access'),
                  onPressed: state.phase == CallV2RuntimePhase.connecting
                      ? _requestInternalAccess
                      : null,
                  child: const Text('Request internal access'),
                ),
                FilledButton(
                  key: const ValueKey<String>('initialize-internal-rtc'),
                  onPressed: state.phase == CallV2RuntimePhase.connecting
                      ? _initializeInternalRtc
                      : null,
                  child: const Text('Initialize internal RTC'),
                ),
                FilledButton(
                  key: const ValueKey<String>('join-internal-rtc'),
                  onPressed: state.phase == CallV2RuntimePhase.connecting
                      ? _joinInternalRtc
                      : null,
                  child: const Text('Join internal RTC'),
                ),
                FilledButton(
                  key: const ValueKey<String>('activate-call'),
                  onPressed: state.phase == CallV2RuntimePhase.ready
                      ? _activateCall
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

  Future<void> _requestPermissions() {
    final runtime = _runtime;
    if (runtime is FakeCallV2Runtime) {
      return runtime.requestRequiredPermissions();
    }
    if (runtime is InternalCallV2Runtime) {
      return runtime.requestPermissionsExplicitly();
    }
    return Future<void>.value();
  }

  Future<void> _connectFakeRtc() {
    final runtime = _runtime;
    if (runtime is FakeCallV2Runtime) {
      return runtime.connectFakeRtc();
    }
    return Future<void>.value();
  }

  Future<void> _requestInternalAccess() {
    final runtime = _runtime;
    if (runtime is InternalCallV2Runtime) {
      return runtime.requestTokenExplicitly();
    }
    return Future<void>.value();
  }

  Future<void> _initializeInternalRtc() {
    final runtime = _runtime;
    if (runtime is InternalCallV2Runtime) {
      return runtime.initializeRtcExplicitly();
    }
    return Future<void>.value();
  }

  Future<void> _joinInternalRtc() {
    final runtime = _runtime;
    if (runtime is InternalCallV2Runtime) {
      return runtime.joinRtcExplicitly();
    }
    return Future<void>.value();
  }

  Future<void> _activateCall() {
    final runtime = _runtime;
    if (runtime is FakeCallV2Runtime) {
      return runtime.activateCall();
    }
    if (runtime is InternalCallV2Runtime) {
      return runtime.activateCall();
    }
    return Future<void>.value();
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
