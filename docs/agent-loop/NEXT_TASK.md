# Active Task — Phase 2L

Branch: `call-v2`
Accepted checkpoint: `adc42c96b75dbf64bb41ee5eb52ce6e4dcd1c3c8`
Implementation commit message: `feat(call-v2): add canary observability and secret hardening`

## Goal

Prepare Call System V2 for a controlled backend canary by adding privacy-safe structured operational observability, hardening rollout-salt handling, and documenting exact canary/rollback checks.

Do not deploy, enable any kill switch, connect Flutter, contact production services, change durable lifecycle semantics, change Cloud Tasks payloads, or alter legacy V1 behavior.

## Allowed files

- `connect_functions/call_v2/**`
- `connect_functions/test/call_v2/**`
- `connect_functions/index.js`
- `connect_functions/package*.json`
- `docs/call-v2/**`

## Rollout-salt hardening

The percentage-rollout salt is currently a normal string parameter. Move production wiring to a protected Firebase secret parameter where supported.

Requirements:
- declare the salt as a secret, not a public/string runtime parameter
- bind the secret only to the seven V2 callable exports that need start-call rollout evaluation
- internal task trigger, timeout endpoint, and scheduled recovery must not receive or depend on the rollout salt
- resolve the secret lazily at invocation time
- no secret read during module import
- existing-call commands may share the same callable wiring object but must not expose or log the salt
- deployment-validation CLI may continue reading an explicit environment value only for offline validation
- no secret value in responses, logs, Firestore, handoff, or tests
- both existing kill switches remain default false

## Privacy-safe observability

Create a dependency-injected module such as:

`connect_functions/call_v2/observability_v2.js`

Provide a narrow sink contract, for example:

```js
recordOperationalEvent({ eventName, outcome, fields })
```

Production wiring may use structured `console.info`/`console.warn`, but domain modules must remain independent of console/global logging.

Supported event names must be allowlisted and versioned. Cover at least:
- client callable outcome
- start-call rollout decision category
- outbox dispatch outcome
- scheduled recovery aggregate outcome
- timeout HTTP authentication/result category

Allowed fields must be bounded low-cardinality operational values only, such as:
- schemaVersion
- eventName
- outcome
- callableName
- rolloutMode
- taskKind
- HTTP status category
- aggregate counters from scheduled recovery
- retryable boolean

Never record:
- raw UID, call ID, task ID, command ID, channel name, chat ID
- payloads or request bodies
- allowlist entries
- rollout salt or bucket
- custom claims
- bearer tokens or OIDC claims
- service-account email
- target URL/audience
- fencing tokens, lock claims, provider messages, stack traces, or credentials

Unknown event names, fields, outcomes, oversized strings, negative counters, or non-plain values must be rejected or dropped deterministically. Logging failure must never change lifecycle behavior or client responses.

## Wiring behavior

Instrument only the Firebase wiring boundary, not durable lifecycle reducers.

Requirements:
- callable success/failure emits a safe event after authentication/policy processing
- start-call rollout denial uses a generic category and must not expose exact reason, staff status, allowlist membership, or bucket
- outbox-created trigger records only normalized dispatcher outcome/retry category
- scheduled recovery records aggregate counts only
- timeout HTTP wrapper records only verification/result category and status class
- no duplicate event for one boundary outcome
- internal task processing remains independent from client rollout eligibility
- event recording is best-effort and non-authoritative

Add a separate observability switch if useful, default false. A disabled observability path must have effectively zero behavior beyond a cheap boolean check.

## Deployment readiness

Extend the deployment validator with a sanitized canary-readiness section.

When client rollout is enabled, require explicit acknowledgement that:
- safe observability is configured
- an operational owner is assigned
- a rollback owner is assigned
- staff custom claims are managed when staff mode is used

Internal-only mode may remain valid without client-canary acknowledgements.
Both switches false must remain valid for code-only deployment.

Sanitized output may expose booleans and rollout mode/percentage/count, but never names, emails, identifiers, URLs, salts, allowlists, or secrets.

## Documentation

Create:

`docs/call-v2/PHASE_2L_CANARY_OBSERVABILITY.md`

Document:
- protected rollout-salt handling
- safe event schema and prohibited data
- exact canary enablement order
- required dashboards/alerts as placeholders without invented project values
- metrics to watch: callable failures, rollout denials, pending age, dispatch retry/dead-letter, timeout retries, unauthorized endpoint requests, lock recovery, terminalization correctness
- rollback order: disable client switch first, keep internal processing on to drain, then disable internal processing after drain
- no deployment performed and both switches remained false

## Required tests

Keep all existing 212 tests passing and add focused coverage proving:
- salt is declared/bound as a secret and not read at import
- internal exports do not receive the rollout salt secret
- event allowlist/schema validation
- prohibited identifiers, payloads, tokens, claims, URLs, emails, salt, bucket, and stack fields cannot be recorded
- oversized/high-cardinality fields are rejected or normalized
- logger failure does not alter callable/trigger/HTTP outcomes
- one normalized event per boundary outcome
- start rollout denial stays generic
- scheduled recovery logs aggregate counts only
- disabled observability emits nothing
- validator safe/unsafe canary acknowledgement combinations
- sanitized CLI output contains no protected values
- legacy exports and behavior remain unchanged
- no production service is contacted

## Validation

Use Node 20 and run:

```bash
cd connect_functions
node --version
npm install
npm run check:call-v2
npm run validate:call-v2:deployment
npm run test:call-v2:rules
npm run test:call-v2:emulator
npm run test:call-v2:emulator
npm run test:call-v2:emulator
node --check index.js
cd ..
git diff --check
```

Do not run `firebase deploy`.

## Handoff

Summarize exact files, secret binding behavior, safe event schema, instrumentation boundaries, validator changes, test totals and three emulator runs, Node version, remaining risks, and Phase 2M recommendation. Confirm no production values were invented, no production service was contacted, nothing was deployed, and both kill switches remain false.
