import 'call_v2_callable_results.dart';

enum CallV2Environment {
  local,
  development,
  staging,
  production,
}

enum CallV2RtcProviderKind {
  none,
  fake,
  agora,
}

class CallV2RuntimeConfiguration {
  const CallV2RuntimeConfiguration({
    required this.enabled,
    required this.environment,
    required this.rtcProvider,
    required this.rtcAppIdReference,
    required this.callCollectionName,
    required this.participantSubcollectionName,
    required this.rtcTokenMaxLifetime,
    required this.minimumTokenRemainingValidity,
  });

  final bool enabled;
  final CallV2Environment environment;
  final CallV2RtcProviderKind rtcProvider;
  final String rtcAppIdReference;
  final String callCollectionName;
  final String participantSubcollectionName;
  final Duration rtcTokenMaxLifetime;
  final Duration minimumTokenRemainingValidity;

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'enabled': enabled,
      'environment': environment.name,
      'rtcProvider': rtcProvider.name,
      'rtcAppIdReference': rtcAppIdReference,
      'callCollectionName': callCollectionName,
      'participantSubcollectionName': participantSubcollectionName,
      'rtcMaxLifetimeSeconds': rtcTokenMaxLifetime.inSeconds,
      'minimumRemainingValiditySeconds':
          minimumTokenRemainingValidity.inSeconds,
    };
  }

  @override
  String toString() {
    return 'CallV2RuntimeConfiguration(${toSafeDebugMap()})';
  }
}

class CallV2RuntimeConfigurationValidation {
  const CallV2RuntimeConfigurationValidation({required this.issues});

  final List<CallV2RuntimeConfigurationIssue> issues;

  bool get isValid => issues.isEmpty;

  @override
  String toString() {
    return 'CallV2RuntimeConfigurationValidation('
        'isValid: $isValid, '
        'issues: ${issues.map((issue) => issue.code.name).toList()}'
        ')';
  }
}

class CallV2RuntimeConfigurationIssue {
  const CallV2RuntimeConfigurationIssue({
    required this.code,
    required this.field,
  });

  final CallV2RuntimeConfigurationIssueCode code;
  final String field;

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'code': code.name,
      'field': field,
    };
  }

  @override
  String toString() {
    return 'CallV2RuntimeConfigurationIssue(${toSafeDebugMap()})';
  }
}

enum CallV2RuntimeConfigurationIssueCode {
  disabledProductionRuntime,
  missingRtcProvider,
  invalidEnvironment,
  missingRtcAppIdReference,
  invalidCollectionName,
  invalidParticipantCollectionName,
  invalidTokenLifetime,
  invalidMinimumRemainingValidity,
  minimumValidityExceedsLifetime,
  fakeProviderForbiddenInProduction,
}

const callV2AcceptedRtcTokenMaxLifetime = Duration(minutes: 15);
const callV2DefaultRuntimeConfiguration = CallV2RuntimeConfiguration(
  enabled: false,
  environment: CallV2Environment.local,
  rtcProvider: CallV2RtcProviderKind.none,
  rtcAppIdReference: '',
  callCollectionName: 'calls',
  participantSubcollectionName: 'participants',
  rtcTokenMaxLifetime: callV2AcceptedRtcTokenMaxLifetime,
  minimumTokenRemainingValidity: Duration(seconds: 60),
);

bool callV2IsSafeConfigurationIdentifier(String value) {
  return value.isNotEmpty &&
      value.trim() == value &&
      value.length <= callV2MaxCallableIdentifierLength &&
      !value.contains('/');
}
