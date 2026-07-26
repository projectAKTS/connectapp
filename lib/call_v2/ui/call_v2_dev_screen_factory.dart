import 'package:flutter/widgets.dart';

import '../runtime/call_v2_runtime_config.dart';
import '../runtime/call_v2_runtime_factory.dart';
import '../runtime/call_v2_runtime_mode.dart';
import 'call_v2_dev_screen.dart';

class CallV2DevScreenFactory {
  const CallV2DevScreenFactory({
    this.runtimeFactory = const CallV2RuntimeFactory(),
  });

  final CallV2RuntimeFactory runtimeFactory;

  Widget create({
    CallV2RuntimeConfig config = const CallV2RuntimeConfig.fake(),
  }) {
    final runtime = runtimeFactory.create(config);
    return CallV2DevScreen(runtime: runtime);
  }

  Map<String, Object?> describe({
    CallV2RuntimeConfig config = const CallV2RuntimeConfig.fake(),
  }) {
    return <String, Object?>{
      'mode': config.toSafeDebugMap()['mode'],
      'fakeDefault': config.mode == CallV2RuntimeMode.fake,
      'devUiExposed': config.exposeDevUi,
      'rolloutEnabled': config.productionRolloutEnabled,
    };
  }
}
