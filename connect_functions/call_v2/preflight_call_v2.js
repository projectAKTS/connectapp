"use strict";

const {
  createDeploymentPreflightReportV2,
} = require("./deployment_preflight_v2");

function main() {
  const report = createDeploymentPreflightReportV2({
    codeOnlyValidationPassed: readBoolean("CALL_V2_CODE_ONLY_VALIDATION_PASSED"),
    productionKillSwitchesFalse: readBoolean("CALL_V2_PRODUCTION_KILL_SWITCHES_FALSE"),
    deploymentValidatorPassed: readBoolean("CALL_V2_DEPLOYMENT_VALIDATOR_PASSED"),
    firestoreIndexReady: readBoolean("CALL_V2_FIRESTORE_INDEX_READY"),
    ttlPoliciesReady: readBoolean("CALL_V2_TTL_POLICIES_READY"),
    cloudTasksReady: readBoolean("CALL_V2_CLOUD_TASKS_READY"),
    oidcReady: readBoolean("CALL_V2_OIDC_READY"),
    observabilityReady: readBoolean("CALL_V2_OBSERVABILITY_READY"),
    operationalOwnerAssigned: readBoolean("CALL_V2_OPERATIONAL_OWNER_ASSIGNED"),
    rollbackOwnerAssigned: readBoolean("CALL_V2_ROLLBACK_OWNER_ASSIGNED"),
    rolloutModeApproved: readBoolean("CALL_V2_ROLLOUT_MODE_APPROVED"),
    rolloutMode: readString("CALL_V2_ROLLOUT_MODE"),
    rolloutPercentage: readInteger("CALL_V2_ROLLOUT_PERCENTAGE"),
    rolloutAllowlistCount: readInteger("CALL_V2_ROLLOUT_ALLOWLIST_COUNT"),
    staffClaimsRequired: readBoolean("CALL_V2_STAFF_CLAIMS_REQUIRED"),
    staffClaimsManaged: readBoolean("CALL_V2_STAFF_CLAIMS_MANAGED"),
    emulatorRunsPassed: readBoolean("CALL_V2_EMULATOR_RUNS_PASSED"),
    rulesTestsPassed: readBoolean("CALL_V2_RULES_TESTS_PASSED"),
    privateDataFindingResolved: readBoolean("CALL_V2_PRIVATE_DATA_FINDING_RESOLVED"),
  });
  const output = { ok: report.status === "ready_for_human_approval", ...report };
  process.stdout.write(`${JSON.stringify(output, null, 2)}\n`);
  if (report.status !== "ready_for_human_approval") {
    process.exitCode = 1;
  }
  return output;
}

function readBoolean(name) {
  const value = `${process.env[name] || ""}`.trim().toLowerCase();
  return value === "true" || value === "1" || value === "yes";
}

function readString(name) {
  const value = `${process.env[name] || ""}`.trim();
  return value || undefined;
}

function readInteger(name) {
  const value = `${process.env[name] || ""}`.trim();
  if (!value) {
    return undefined;
  }
  const parsed = Number(value);
  return Number.isSafeInteger(parsed) ? parsed : undefined;
}

if (require.main === module) {
  main();
}

module.exports = { main };
