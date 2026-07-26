import 'package:flutter/material.dart';

import '../runtime/call_v2_runtime_config.dart';
import '../runtime/call_v2_runtime_factory.dart';
import 'call_v2_dev_screen_factory.dart';

enum CallV2ManualDevMode {
  fake,
  internalFakeAdapters,
  internalRealAdapters,
}

class CallV2ManualDevEntry extends StatefulWidget {
  const CallV2ManualDevEntry({
    super.key,
    this.screenFactory = const CallV2DevScreenFactory(),
    this.realAdapterFactory,
  });

  final CallV2DevScreenFactory screenFactory;
  final CallV2RuntimeFactory? realAdapterFactory;

  @override
  State<CallV2ManualDevEntry> createState() => _CallV2ManualDevEntryState();
}

class _CallV2ManualDevEntryState extends State<CallV2ManualDevEntry> {
  CallV2ManualDevMode _mode = CallV2ManualDevMode.fake;

  @override
  Widget build(BuildContext context) {
    final config = _configFor(_mode);
    final factory = _mode == CallV2ManualDevMode.internalRealAdapters &&
            widget.realAdapterFactory != null
        ? CallV2DevScreenFactory(runtimeFactory: widget.realAdapterFactory!)
        : widget.screenFactory;

    return Column(
      key: const ValueKey<String>('call-v2-manual-dev-entry'),
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
        Expanded(
          child: factory.create(config: config),
        ),
      ],
    );
  }
}

CallV2RuntimeConfig _configFor(CallV2ManualDevMode mode) {
  switch (mode) {
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
      return const CallV2RuntimeConfig.internalRealDevice(
        allowPermissionRequests: true,
        allowTokenRequests: true,
        allowRtcInitialization: true,
        allowRtcJoin: true,
        exposeDevUi: true,
        useRealAdapters: true,
      );
  }
}
