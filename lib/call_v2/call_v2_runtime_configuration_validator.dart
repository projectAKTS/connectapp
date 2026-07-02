import 'call_v2_runtime_configuration.dart';

class CallV2RuntimeConfigurationValidator {
  const CallV2RuntimeConfigurationValidator();

  CallV2RuntimeConfigurationValidation validate(
    CallV2RuntimeConfiguration configuration,
  ) {
    final issues = <CallV2RuntimeConfigurationIssue>[];

    _validateEnvironment(configuration, issues);
    _validateProvider(configuration, issues);
    _validateAppReference(configuration, issues);
    _validateCollections(configuration, issues);
    _validateLifetimes(configuration, issues);

    return CallV2RuntimeConfigurationValidation(
      issues: List<CallV2RuntimeConfigurationIssue>.unmodifiable(issues),
    );
  }

  void _validateEnvironment(
    CallV2RuntimeConfiguration configuration,
    List<CallV2RuntimeConfigurationIssue> issues,
  ) {
    if (!CallV2Environment.values.contains(configuration.environment)) {
      issues.add(const CallV2RuntimeConfigurationIssue(
        code: CallV2RuntimeConfigurationIssueCode.invalidEnvironment,
        field: 'environment',
      ));
    }
  }

  void _validateProvider(
    CallV2RuntimeConfiguration configuration,
    List<CallV2RuntimeConfigurationIssue> issues,
  ) {
    if (!configuration.enabled) return;

    if (configuration.rtcProvider == CallV2RtcProviderKind.none) {
      issues.add(const CallV2RuntimeConfigurationIssue(
        code: CallV2RuntimeConfigurationIssueCode.missingRtcProvider,
        field: 'rtcProvider',
      ));
    }

    if (configuration.environment == CallV2Environment.production &&
        configuration.rtcProvider == CallV2RtcProviderKind.fake) {
      issues.add(const CallV2RuntimeConfigurationIssue(
        code: CallV2RuntimeConfigurationIssueCode
            .fakeProviderForbiddenInProduction,
        field: 'rtcProvider',
      ));
    }
  }

  void _validateAppReference(
    CallV2RuntimeConfiguration configuration,
    List<CallV2RuntimeConfigurationIssue> issues,
  ) {
    if (!configuration.enabled ||
        configuration.rtcProvider != CallV2RtcProviderKind.agora) {
      return;
    }
    if (!callV2IsSafeConfigurationIdentifier(configuration.rtcAppIdReference)) {
      issues.add(const CallV2RuntimeConfigurationIssue(
        code: CallV2RuntimeConfigurationIssueCode.missingRtcAppIdReference,
        field: 'rtcAppIdReference',
      ));
    }
  }

  void _validateCollections(
    CallV2RuntimeConfiguration configuration,
    List<CallV2RuntimeConfigurationIssue> issues,
  ) {
    if (!callV2IsSafeConfigurationIdentifier(
      configuration.callCollectionName,
    )) {
      issues.add(const CallV2RuntimeConfigurationIssue(
        code: CallV2RuntimeConfigurationIssueCode.invalidCollectionName,
        field: 'callCollectionName',
      ));
    }
    if (!callV2IsSafeConfigurationIdentifier(
      configuration.participantSubcollectionName,
    )) {
      issues.add(const CallV2RuntimeConfigurationIssue(
        code: CallV2RuntimeConfigurationIssueCode
            .invalidParticipantCollectionName,
        field: 'participantSubcollectionName',
      ));
    }
  }

  void _validateLifetimes(
    CallV2RuntimeConfiguration configuration,
    List<CallV2RuntimeConfigurationIssue> issues,
  ) {
    final tokenLifetime = configuration.rtcTokenMaxLifetime;
    final minimumValidity = configuration.minimumTokenRemainingValidity;

    if (tokenLifetime <= Duration.zero ||
        tokenLifetime > callV2AcceptedRtcTokenMaxLifetime) {
      issues.add(const CallV2RuntimeConfigurationIssue(
        code: CallV2RuntimeConfigurationIssueCode.invalidTokenLifetime,
        field: 'rtcTokenMaxLifetime',
      ));
    }
    if (minimumValidity <= Duration.zero) {
      issues.add(const CallV2RuntimeConfigurationIssue(
        code:
            CallV2RuntimeConfigurationIssueCode.invalidMinimumRemainingValidity,
        field: 'minimumTokenRemainingValidity',
      ));
    }
    if (minimumValidity >= tokenLifetime) {
      issues.add(const CallV2RuntimeConfigurationIssue(
        code:
            CallV2RuntimeConfigurationIssueCode.minimumValidityExceedsLifetime,
        field: 'minimumTokenRemainingValidity',
      ));
    }
  }
}

CallV2RuntimeConfigurationValidation validateCallV2RuntimeConfiguration(
  CallV2RuntimeConfiguration configuration,
) {
  return const CallV2RuntimeConfigurationValidator().validate(configuration);
}
