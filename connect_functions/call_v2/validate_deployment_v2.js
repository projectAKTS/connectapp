#!/usr/bin/env node
"use strict";

const {
  validateCallV2DeploymentConfig,
} = require("./deployment_readiness_v2");

function main() {
  try {
    const result = validateCallV2DeploymentConfig({
      clientEnabled: readBoolean("CALL_V2_ENABLED"),
      internalTasksEnabled: readBoolean("CALL_V2_INTERNAL_TASKS_ENABLED"),
      region: readString("CALL_V2_REGION"),
      projectId: readString("CALL_V2_TASKS_PROJECT_ID"),
      location: readString("CALL_V2_TASKS_LOCATION"),
      queueId: readString("CALL_V2_TASKS_QUEUE_ID"),
      targetUrl: readString("CALL_V2_TASKS_TARGET_URL"),
      serviceAccountEmail: readString("CALL_V2_TASKS_SERVICE_ACCOUNT_EMAIL"),
      audience: readString("CALL_V2_TASKS_AUDIENCE"),
      allowDistinctAudience: readBoolean("CALL_V2_ALLOW_DISTINCT_AUDIENCE"),
    });
    process.stdout.write(`${JSON.stringify({
      ok: true,
      ...result,
    }, null, 2)}\n`);
  } catch (error) {
    process.stdout.write(`${JSON.stringify({
      ok: false,
      status: "invalid",
      code: error && error.code ? error.code : "invalid_argument",
      message: "Call V2 deployment configuration is not ready.",
    }, null, 2)}\n`);
    process.exitCode = 1;
  }
}

function readBoolean(name) {
  const value = `${process.env[name] || ""}`.trim().toLowerCase();
  return value === "true" || value === "1" || value === "yes";
}

function readString(name) {
  return `${process.env[name] || ""}`.trim();
}

if (require.main === module) {
  main();
}

module.exports = {
  main,
};
