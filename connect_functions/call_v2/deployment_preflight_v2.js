"use strict";

const STAGE_NAMES = Object.freeze([
  "code_only_validation",
  "firestore_index",
  "ttl_policies",
  "cloud_tasks",
  "oidc",
  "observability",
  "ownership",
  "rollout",
  "staff_claims",
  "emulators",
  "rules",
  "private_data",
]);

const BLOCKER_CODES = Object.freeze({
  kill_switches_enabled: "kill_switches_enabled",
  deployment_validator_not_passed: "deployment_validator_not_passed",
  firestore_index_missing: "firestore_index_missing",
  ttl_policies_missing: "ttl_policies_missing",
  cloud_tasks_not_ready: "cloud_tasks_not_ready",
  oidc_not_ready: "oidc_not_ready",
  observability_missing: "observability_missing",
  operational_owner_missing: "operational_owner_missing",
  rollback_owner_missing: "rollback_owner_missing",
  rollout_mode_incomplete: "rollout_mode_incomplete",
  staff_claims_missing: "staff_claims_missing",
  emulator_runs_missing: "emulator_runs_missing",
  rules_tests_missing: "rules_tests_missing",
  private_data_risk_unresolved: "private_data_risk_unresolved",
  unknown_fields_present: "unknown_fields_present",
  incomplete_sanitized_input: "incomplete_sanitized_input",
});

const ALLOWED_INPUT_KEYS = Object.freeze([
  "codeOnlyValidationPassed",
  "productionKillSwitchesFalse",
  "deploymentValidatorPassed",
  "firestoreIndexReady",
  "ttlPoliciesReady",
  "cloudTasksReady",
  "oidcReady",
  "observabilityReady",
  "operationalOwnerAssigned",
  "rollbackOwnerAssigned",
  "rolloutModeApproved",
  "rolloutMode",
  "rolloutPercentage",
  "rolloutAllowlistCount",
  "staffClaimsRequired",
  "staffClaimsManaged",
  "emulatorRunsPassed",
  "rulesTestsPassed",
  "privateDataFindingResolved",
]);

function createDeploymentPreflightReportV2(input = {}) {
  const sanitized = sanitizeInput(input);
  const report = evaluatePreflight(sanitized);
  return Object.freeze(report);
}

function evaluatePreflight(input) {
  if (input.unknownFieldsPresent === true) {
    return {
      status: "blocked",
      stageNames: STAGE_NAMES,
      checks: Object.freeze({
        codeOnlyValidationPassed: false,
        productionKillSwitchesFalse: false,
        deploymentValidatorPassed: false,
        firestoreIndexReady: false,
        ttlPoliciesReady: false,
        cloudTasksReady: false,
        oidcReady: false,
        observabilityReady: false,
        operationalOwnerAssigned: false,
        rollbackOwnerAssigned: false,
        rolloutModeApproved: false,
        staffClaimsRequired: false,
        staffClaimsManaged: false,
        emulatorRunsPassed: false,
        rulesTestsPassed: false,
        privateDataFindingResolved: false,
      }),
      blockerCodes: Object.freeze([BLOCKER_CODES.unknown_fields_present]),
    };
  }
  const checks = Object.freeze({
    codeOnlyValidationPassed: input.codeOnlyValidationPassed === true,
    productionKillSwitchesFalse: input.productionKillSwitchesFalse === true,
    deploymentValidatorPassed: input.deploymentValidatorPassed === true,
    firestoreIndexReady: input.firestoreIndexReady === true,
    ttlPoliciesReady: input.ttlPoliciesReady === true,
    cloudTasksReady: input.cloudTasksReady === true,
    oidcReady: input.oidcReady === true,
    observabilityReady: input.observabilityReady === true,
    operationalOwnerAssigned: input.operationalOwnerAssigned === true,
    rollbackOwnerAssigned: input.rollbackOwnerAssigned === true,
    rolloutModeApproved: input.rolloutModeApproved === true,
    staffClaimsRequired: input.staffClaimsRequired === true,
    staffClaimsManaged: input.staffClaimsManaged === true,
    emulatorRunsPassed: input.emulatorRunsPassed === true,
    rulesTestsPassed: input.rulesTestsPassed === true,
    privateDataFindingResolved: input.privateDataFindingResolved === true,
  });

  const blockerCodes = [];
  if (!checks.codeOnlyValidationPassed || !checks.productionKillSwitchesFalse) {
    blockerCodes.push(BLOCKER_CODES.kill_switches_enabled);
  }
  if (!checks.deploymentValidatorPassed) {
    blockerCodes.push(BLOCKER_CODES.deployment_validator_not_passed);
  }
  if (!checks.firestoreIndexReady) {
    blockerCodes.push(BLOCKER_CODES.firestore_index_missing);
  }
  if (!checks.ttlPoliciesReady) {
    blockerCodes.push(BLOCKER_CODES.ttl_policies_missing);
  }
  if (!checks.cloudTasksReady) {
    blockerCodes.push(BLOCKER_CODES.cloud_tasks_not_ready);
  }
  if (!checks.oidcReady) {
    blockerCodes.push(BLOCKER_CODES.oidc_not_ready);
  }
  if (!checks.observabilityReady) {
    blockerCodes.push(BLOCKER_CODES.observability_missing);
  }
  if (!checks.operationalOwnerAssigned) {
    blockerCodes.push(BLOCKER_CODES.operational_owner_missing);
  }
  if (!checks.rollbackOwnerAssigned) {
    blockerCodes.push(BLOCKER_CODES.rollback_owner_missing);
  }
  if (!checks.rolloutModeApproved) {
    blockerCodes.push(BLOCKER_CODES.rollout_mode_incomplete);
  }
  if (checks.staffClaimsRequired && !checks.staffClaimsManaged) {
    blockerCodes.push(BLOCKER_CODES.staff_claims_missing);
  }
  if (!checks.emulatorRunsPassed) {
    blockerCodes.push(BLOCKER_CODES.emulator_runs_missing);
  }
  if (!checks.rulesTestsPassed) {
    blockerCodes.push(BLOCKER_CODES.rules_tests_missing);
  }
  if (!checks.privateDataFindingResolved) {
    blockerCodes.push(BLOCKER_CODES.private_data_risk_unresolved);
  }

  const complete = blockerCodes.length === 0;
  return {
    status: complete ? "ready_for_human_approval" : "blocked",
    stageNames: STAGE_NAMES,
    checks,
    blockerCodes: Object.freeze(blockerCodes),
    rolloutMode: sanitizeString(input.rolloutMode),
    rolloutPercentage: sanitizeOptionalInteger(input.rolloutPercentage),
    rolloutAllowlistCount: sanitizeOptionalInteger(input.rolloutAllowlistCount),
  };
}

function sanitizeInput(input) {
  if (!isPlainObject(input)) {
    return Object.freeze({});
  }
  const unknownFields = Object.keys(input).filter((key) => !ALLOWED_INPUT_KEYS.includes(key));
  if (unknownFields.length > 0) {
    return Object.freeze({
      unknownFieldsPresent: true,
    });
  }
  const sanitized = {};
  for (const key of ALLOWED_INPUT_KEYS) {
    if (Object.prototype.hasOwnProperty.call(input, key)) {
      sanitized[key] = input[key];
    }
  }
  return Object.freeze(sanitized);
}

function isPlainObject(value) {
  return value !== null && typeof value === "object" && Object.getPrototypeOf(value) === Object.prototype;
}

function sanitizeString(value) {
  return typeof value === "string" && value.length > 0 ? value : undefined;
}

function sanitizeOptionalInteger(value) {
  return Number.isSafeInteger(value) ? value : undefined;
}

module.exports = {
  BLOCKER_CODES,
  STAGE_NAMES,
  createDeploymentPreflightReportV2,
};
