import 'package:flutter/material.dart';

import '../firebase/call_v2_callable_transport.dart';
import '../permissions/real_call_v2_permission_adapter.dart';
import '../rtc/agora_call_v2_rtc_adapter.dart';
import '../runtime/call_v2_manual_session_inputs.dart';
import '../runtime/call_v2_runtime_config.dart';
import '../runtime/call_v2_runtime_factory.dart';
import '../runtime/call_v2_runtime_state.dart';
import 'call_v2_dev_screen_factory.dart';
import 'call_v2_manual_dev_entry.dart';

class CallV2ManualDevForm extends StatefulWidget {
  const CallV2ManualDevForm({
    super.key,
    this.screenFactory = const CallV2DevScreenFactory(),
    this.callableTransport,
    this.permissionClient,
    this.rtcClient,
  });

  final CallV2DevScreenFactory screenFactory;
  final CallV2CallableTransport? callableTransport;
  final RealCallV2PermissionClient? permissionClient;
  final AgoraCallV2RtcEngineClient? rtcClient;

  @override
  State<CallV2ManualDevForm> createState() => _CallV2ManualDevFormState();
}

class _CallV2ManualDevFormState extends State<CallV2ManualDevForm> {
  final _applicationController = TextEditingController();
  final _sessionController = TextEditingController(text: 'manual-session');
  final _localController = TextEditingController(text: 'manual-a');
  final _remoteController = TextEditingController(text: 'manual-b');
  CallV2RuntimeCallMode _callMode = CallV2RuntimeCallMode.audio;
  CallV2ManualDevMode _mode = CallV2ManualDevMode.fake;
  Widget? _createdScreen;
  Map<String, Object?>? _safeDebug;
  bool _inputRejected = false;

  @override
  void dispose() {
    _applicationController.dispose();
    _sessionController.dispose();
    _localController.dispose();
    _remoteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screen = _createdScreen;
    return Column(
      key: const ValueKey<String>('call-v2-manual-dev-entry'),
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: <Widget>[
              DropdownButton<CallV2ManualDevMode>(
                key: const ValueKey<String>('call-v2-manual-mode'),
                value: _mode,
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _mode = value);
                },
                items: const <DropdownMenuItem<CallV2ManualDevMode>>[
                  DropdownMenuItem<CallV2ManualDevMode>(
                    value: CallV2ManualDevMode.fake,
                    child: Text('Fake mode'),
                  ),
                  DropdownMenuItem<CallV2ManualDevMode>(
                    value: CallV2ManualDevMode.internalFakeAdapters,
                    child: Text('Internal mode with fake adapters'),
                  ),
                  DropdownMenuItem<CallV2ManualDevMode>(
                    value: CallV2ManualDevMode.internalRealAdapters,
                    child: Text('Internal mode with real adapters'),
                  ),
                ],
              ),
              TextField(
                key: const ValueKey<String>('call-v2-manual-app'),
                controller: _applicationController,
                decoration: const InputDecoration(labelText: 'Agora App ID'),
              ),
              TextField(
                key: const ValueKey<String>('call-v2-manual-session'),
                controller: _sessionController,
                decoration: const InputDecoration(labelText: 'Call/session'),
              ),
              TextField(
                key: const ValueKey<String>('call-v2-manual-local'),
                controller: _localController,
                decoration: const InputDecoration(labelText: 'Local'),
              ),
              TextField(
                key: const ValueKey<String>('call-v2-manual-remote'),
                controller: _remoteController,
                decoration: const InputDecoration(labelText: 'Remote'),
              ),
              SegmentedButton<CallV2RuntimeCallMode>(
                key: const ValueKey<String>('call-v2-manual-media-mode'),
                segments: const <ButtonSegment<CallV2RuntimeCallMode>>[
                  ButtonSegment<CallV2RuntimeCallMode>(
                    value: CallV2RuntimeCallMode.audio,
                    label: Text('Audio'),
                  ),
                  ButtonSegment<CallV2RuntimeCallMode>(
                    value: CallV2RuntimeCallMode.video,
                    label: Text('Video'),
                  ),
                ],
                selected: <CallV2RuntimeCallMode>{_callMode},
                onSelectionChanged: (value) {
                  setState(() => _callMode = value.single);
                },
              ),
              FilledButton(
                key: const ValueKey<String>('call-v2-create-manual-runtime'),
                onPressed: _createManualRuntime,
                child: const Text('Create Manual Runtime'),
              ),
              Text(
                _safeDebug.toString(),
                key: const ValueKey<String>('call-v2-manual-safe-debug'),
              ),
              if (_inputRejected)
                const Text(
                  'Input rejected',
                  key: ValueKey<String>('call-v2-manual-input-rejected'),
                ),
            ],
          ),
        ),
        if (screen != null) Expanded(child: screen),
      ],
    );
  }

  void _createManualRuntime() {
    try {
      final inputs = CallV2ManualSessionInputs(
        rtcApplicationIdentifier: _applicationController.text,
        sessionIdentifier: _sessionController.text,
        localParticipantIdentifier: _localController.text,
        remoteParticipantIdentifier: _remoteController.text,
        mode: _callMode,
        useRealAdapters: _mode == CallV2ManualDevMode.internalRealAdapters,
        allowPermissionRequests: true,
        allowTokenRequests: true,
        allowRtcInitialization: true,
        allowRtcJoin: true,
      );
      final config = _configForMode(inputs);
      final factory = _factoryForMode(inputs);
      setState(() {
        _inputRejected = false;
        _safeDebug = inputs.toSafeDebugMap();
        _createdScreen = factory.create(config: config);
      });
    } on CallV2ManualSessionInputError {
      setState(() {
        _inputRejected = true;
        _safeDebug = const <String, Object?>{'inputReady': false};
        _createdScreen = null;
      });
    }
  }

  CallV2RuntimeConfig _configForMode(CallV2ManualSessionInputs inputs) {
    switch (_mode) {
      case CallV2ManualDevMode.fake:
        return const CallV2RuntimeConfig.fake();
      case CallV2ManualDevMode.internalFakeAdapters:
        return const CallV2RuntimeConfig.internalRealDevice(
          allowPermissionRequests: true,
          allowTokenRequests: true,
          allowRtcInitialization: true,
          allowRtcJoin: true,
          exposeDevUi: true,
        );
      case CallV2ManualDevMode.internalRealAdapters:
        return inputs.toRuntimeConfig();
    }
  }

  CallV2DevScreenFactory _factoryForMode(CallV2ManualSessionInputs inputs) {
    if (_mode != CallV2ManualDevMode.internalRealAdapters) {
      return widget.screenFactory;
    }
    return CallV2DevScreenFactory(
      runtimeFactory: CallV2RuntimeFactory.manualRealDevice(
        inputs: inputs,
        transport: widget.callableTransport,
        permissionClient: widget.permissionClient,
        rtcClient: widget.rtcClient,
      ),
    );
  }
}
