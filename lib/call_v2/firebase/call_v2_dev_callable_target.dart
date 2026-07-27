import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_call_v2_callable_transport.dart';

const CallV2DevCallableTargetConfig helperlyCallV2DevCallableTargetConfig =
    CallV2DevCallableTargetConfig(
  appName: 'helperly-call-v2-dev-manual',
  projectId: 'helperly-call-v2-dev',
  functionsRegion: 'us-central1',
  apiKey: 'AIzaSyBwulFJvkfoIzA0tSROEEakHZpKB1BL2b8',
  appId: '1:270649452680:ios:dbf244b01c661b48be973d',
  messagingSenderId: '270649452680',
);

class CallV2DevCallableTargetConfig {
  const CallV2DevCallableTargetConfig({
    required this.appName,
    required this.projectId,
    required this.functionsRegion,
    required this.apiKey,
    required this.appId,
    required this.messagingSenderId,
  });

  final String appName;
  final String projectId;
  final String functionsRegion;
  final String apiKey;
  final String appId;
  final String messagingSenderId;

  bool get isReady {
    return appName.isNotEmpty &&
        projectId == 'helperly-call-v2-dev' &&
        functionsRegion == 'us-central1' &&
        apiKey.isNotEmpty &&
        appId.isNotEmpty &&
        messagingSenderId.isNotEmpty;
  }

  FirebaseOptions toFirebaseOptions() {
    return FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: messagingSenderId,
      projectId: projectId,
      storageBucket: '$projectId.firebasestorage.app',
    );
  }

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'devTargetReady': isReady,
      'callableReachable': false,
      'selectedRegion': functionsRegion,
    };
  }

  @override
  String toString() => 'CallV2DevCallableTargetConfig(${toSafeDebugMap()})';
}

abstract interface class CallV2DevCallableTarget {
  Future<FirebaseCallV2CallableTransport> createTransport();

  Map<String, Object?> toSafeDebugMap();
}

class FirebaseCallV2DevCallableTarget implements CallV2DevCallableTarget {
  const FirebaseCallV2DevCallableTarget({
    this.config = helperlyCallV2DevCallableTargetConfig,
  });

  final CallV2DevCallableTargetConfig config;

  @override
  Future<FirebaseCallV2CallableTransport> createTransport() async {
    if (!config.isReady) {
      throw const FirebaseCallV2DevCallableTargetError();
    }
    final app = await _secondaryApp(config);
    return FirebaseCallV2CallableTransport.cloudFunctions(
      functions: FirebaseFunctions.instanceFor(
        app: app,
        region: config.functionsRegion,
      ),
    );
  }

  @override
  Map<String, Object?> toSafeDebugMap() {
    return config.toSafeDebugMap();
  }

  @override
  String toString() => 'FirebaseCallV2DevCallableTarget(${toSafeDebugMap()})';
}

class FirebaseCallV2DevCallableTargetError implements Exception {
  const FirebaseCallV2DevCallableTargetError();
}

Future<FirebaseApp> _secondaryApp(CallV2DevCallableTargetConfig config) async {
  try {
    return Firebase.app(config.appName);
  } on FirebaseException catch (error) {
    if (error.code != 'no-app') {
      rethrow;
    }
  }
  return Firebase.initializeApp(
    name: config.appName,
    options: config.toFirebaseOptions(),
  );
}
