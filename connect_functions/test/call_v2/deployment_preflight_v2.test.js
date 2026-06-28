"use strict";

const assert = require("node:assert/strict");
const { test } = require("node:test");

const {
  BLOCKER_CODES,
  STAGE_NAMES,
  createDeploymentPreflightReportV2,
} = require("../../call_v2/deployment_preflight_v2");
const { main } = require("../../call_v2/preflight_call_v2");

test("default preflight is blocked, sanitized, deterministic, and immutable", () => {
  const report = createDeploymentPreflightReportV2();
  assert.equal(report.status, "blocked");
  assert.deepEqual(report.stageNames, STAGE_NAMES);
  assert.ok(report.blockerCodes.includes(BLOCKER_CODES.kill_switches_enabled));
  assert.equal(JSON.stringify(report).includes("secret"), false);
  assert.throws(() => {
    report.stageNames.push("extra");
  });
  assert.throws(() => {
    report.blockerCodes.push("extra");
  });
});

test("every missing gate yields a controlled blocker code", () => {
  const report = createDeploymentPreflightReportV2({
    codeOnlyValidationPassed: true,
    productionKillSwitchesFalse: true,
  });
  assert.deepEqual(report.blockerCodes, [
    BLOCKER_CODES.deployment_validator_not_passed,
    BLOCKER_CODES.firestore_index_missing,
    BLOCKER_CODES.ttl_policies_missing,
    BLOCKER_CODES.cloud_tasks_not_ready,
    BLOCKER_CODES.oidc_not_ready,
    BLOCKER_CODES.observability_missing,
    BLOCKER_CODES.operational_owner_missing,
    BLOCKER_CODES.rollback_owner_missing,
    BLOCKER_CODES.rollout_mode_incomplete,
    BLOCKER_CODES.emulator_runs_missing,
    BLOCKER_CODES.rules_tests_missing,
    BLOCKER_CODES.private_data_risk_unresolved,
  ]);
});

test("complete sanitized input is ready for human approval", () => {
  const report = createDeploymentPreflightReportV2({
    codeOnlyValidationPassed: true,
    productionKillSwitchesFalse: true,
    deploymentValidatorPassed: true,
    firestoreIndexReady: true,
    ttlPoliciesReady: true,
    cloudTasksReady: true,
    oidcReady: true,
    observabilityReady: true,
    operationalOwnerAssigned: true,
    rollbackOwnerAssigned: true,
    rolloutModeApproved: true,
    rolloutMode: "staff_only",
    rolloutPercentage: 0,
    rolloutAllowlistCount: 0,
    staffClaimsRequired: true,
    staffClaimsManaged: true,
    emulatorRunsPassed: true,
    rulesTestsPassed: true,
    privateDataFindingResolved: true,
  });
  assert.equal(report.status, "ready_for_human_approval");
  assert.deepEqual(report.blockerCodes, []);
  assert.equal(report.rolloutMode, "staff_only");
  assert.equal(report.rolloutPercentage, 0);
  assert.equal(report.rolloutAllowlistCount, 0);
});

test("controlled rollout metadata is allowlisted and normalized", () => {
  const report = createDeploymentPreflightReportV2({
    codeOnlyValidationPassed: true,
    productionKillSwitchesFalse: true,
    deploymentValidatorPassed: true,
    firestoreIndexReady: true,
    ttlPoliciesReady: true,
    cloudTasksReady: true,
    oidcReady: true,
    observabilityReady: true,
    operationalOwnerAssigned: true,
    rollbackOwnerAssigned: true,
    rolloutModeApproved: true,
    rolloutMode: "  INTERNAL_ONLY  ",
    rolloutPercentage: 100,
    rolloutAllowlistCount: 12,
    staffClaimsRequired: false,
    emulatorRunsPassed: true,
    rulesTestsPassed: true,
    privateDataFindingResolved: true,
  });
  assert.equal(report.status, "ready_for_human_approval");
  assert.equal(report.rolloutMode, "internal_only");
  assert.equal(report.rolloutPercentage, 100);
  assert.equal(report.rolloutAllowlistCount, 12);
});

test("invalid rollout metadata is not echoed and blocks readiness", () => {
  const report = createDeploymentPreflightReportV2({
    codeOnlyValidationPassed: true,
    productionKillSwitchesFalse: true,
    deploymentValidatorPassed: true,
    firestoreIndexReady: true,
    ttlPoliciesReady: true,
    cloudTasksReady: true,
    oidcReady: true,
    observabilityReady: true,
    operationalOwnerAssigned: true,
    rollbackOwnerAssigned: true,
    rolloutModeApproved: true,
    rolloutMode: "https://example.test/rollout?token=secret@example.com",
    rolloutPercentage: 101,
    rolloutAllowlistCount: -1,
    staffClaimsRequired: false,
    emulatorRunsPassed: true,
    rulesTestsPassed: true,
    privateDataFindingResolved: true,
  });
  assert.equal(report.status, "blocked");
  assert.equal(report.rolloutMode, undefined);
  assert.equal(report.rolloutPercentage, undefined);
  assert.equal(report.rolloutAllowlistCount, undefined);
  assert.ok(report.blockerCodes.includes(BLOCKER_CODES.rollout_mode_invalid));
  assert.ok(report.blockerCodes.includes(BLOCKER_CODES.rollout_percentage_invalid));
  assert.ok(report.blockerCodes.includes(BLOCKER_CODES.rollout_allowlist_count_invalid));
  assert.equal(JSON.stringify(report).includes("secret@example.com"), false);
});

test("staff claim requirements apply only when relevant", () => {
  const internalOnly = createDeploymentPreflightReportV2({
    codeOnlyValidationPassed: true,
    productionKillSwitchesFalse: true,
    deploymentValidatorPassed: true,
    firestoreIndexReady: true,
    ttlPoliciesReady: true,
    cloudTasksReady: true,
    oidcReady: true,
    observabilityReady: true,
    operationalOwnerAssigned: true,
    rollbackOwnerAssigned: true,
    rolloutModeApproved: true,
    emulatorRunsPassed: true,
    rulesTestsPassed: true,
    privateDataFindingResolved: true,
  });
  assert.equal(internalOnly.blockerCodes.includes(BLOCKER_CODES.staff_claims_missing), false);

  const staff = createDeploymentPreflightReportV2({
    codeOnlyValidationPassed: true,
    productionKillSwitchesFalse: true,
    deploymentValidatorPassed: true,
    firestoreIndexReady: true,
    ttlPoliciesReady: true,
    cloudTasksReady: true,
    oidcReady: true,
    observabilityReady: true,
    operationalOwnerAssigned: true,
    rollbackOwnerAssigned: true,
    rolloutModeApproved: true,
    staffClaimsRequired: true,
    emulatorRunsPassed: true,
    rulesTestsPassed: true,
    privateDataFindingResolved: true,
  });
  assert.ok(staff.blockerCodes.includes(BLOCKER_CODES.staff_claims_missing));
});

test("unknown fields are rejected deterministically and do not leak values", () => {
  const report = createDeploymentPreflightReportV2({
    codeOnlyValidationPassed: true,
    unexpected: "https://secret.example",
  });
  assert.deepEqual(report.blockerCodes, [BLOCKER_CODES.unknown_fields_present]);
  assert.equal(JSON.stringify(report).includes("secret.example"), false);
});

test("CLI default invocation is blocked and sanitized without initialization", () => {
  const result = runPreflightCli({});
  assert.notEqual(result.status, 0);
  assert.equal(result.output.includes("ready_for_human_approval"), false);
  assert.equal(result.output.includes("firebase"), false);
  assert.equal(result.output.includes("internal_only"), false);
  assert.equal(result.output.includes("staff_only"), false);
  assert.equal(result.output.includes("https://"), false);
});

test("CLI ready output accepts explicit sanitized rollout metadata only", () => {
  const result = runPreflightCli({
    CALL_V2_CODE_ONLY_VALIDATION_PASSED: "true",
    CALL_V2_PRODUCTION_KILL_SWITCHES_FALSE: "true",
    CALL_V2_DEPLOYMENT_VALIDATOR_PASSED: "true",
    CALL_V2_FIRESTORE_INDEX_READY: "true",
    CALL_V2_TTL_POLICIES_READY: "true",
    CALL_V2_CLOUD_TASKS_READY: "true",
    CALL_V2_OIDC_READY: "true",
    CALL_V2_OBSERVABILITY_READY: "true",
    CALL_V2_OPERATIONAL_OWNER_ASSIGNED: "true",
    CALL_V2_ROLLBACK_OWNER_ASSIGNED: "true",
    CALL_V2_ROLLOUT_MODE_APPROVED: "true",
    CALL_V2_ROLLOUT_MODE: "percentage",
    CALL_V2_ROLLOUT_PERCENTAGE: "25",
    CALL_V2_ROLLOUT_ALLOWLIST_COUNT: "0",
    CALL_V2_STAFF_CLAIMS_REQUIRED: "false",
    CALL_V2_EMULATOR_RUNS_PASSED: "true",
    CALL_V2_RULES_TESTS_PASSED: "true",
    CALL_V2_PRIVATE_DATA_FINDING_RESOLVED: "true",
  });
  assert.equal(result.status, 0);
  assert.equal(result.stdout.includes('"ok": true'), true);
  assert.equal(result.stdout.includes('"rolloutMode": "percentage"'), true);
  assert.equal(result.stdout.includes('"rolloutPercentage": 25'), true);
  assert.equal(result.stdout.includes('"rolloutAllowlistCount": 0'), true);
});

function runPreflightCli(env) {
  const originalEnv = process.env;
  const originalWrite = process.stdout.write;
  const originalExitCode = process.exitCode;
  let stdout = "";
  process.env = {
    PATH: originalEnv.PATH,
    ...env,
  };
  process.exitCode = 0;
  process.stdout.write = (chunk) => {
    stdout += chunk;
    return true;
  };
  try {
    const output = main();
    return {
      status: process.exitCode || 0,
      stdout,
      output: JSON.stringify(output),
    };
  } finally {
    process.env = originalEnv;
    process.stdout.write = originalWrite;
    process.exitCode = originalExitCode;
  }
}
