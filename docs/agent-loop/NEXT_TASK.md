# Active Task — Phase 2K

Branch: `call-v2`
Accepted checkpoint: `dd738000c0dfbcdd321860af7d590fb64be85044`
Implementation commit message: `feat(call-v2): add server-side rollout gating`

## Goal

Add server-controlled rollout gating for new V2 calls. Do not deploy, enable kill switches, connect Flutter, change timeout/Cloud Tasks/outbox contracts, or alter legacy V1 behavior.

Allowed files:
- `connect_functions/call_v2/**`
- `connect_functions/test/call_v2/**`
- `connect_functions/index.js`
- `connect_functions/package*.json`
- `docs/call-v2/**`
- `docs/agent-loop/HANDOFF.md`
- `docs/agent-loop/STATE.json`

## Rollout policy

Support exact modes: `off`, `staff`, `allowlist`, `percentage`, `all`.

Add server configuration:
- `CALL_V2_ROLLOUT_MODE` default `off`
- `CALL_V2_ROLLOUT_PERCENTAGE` default `0`
- protected `CALL_V2_ROLLOUT_SALT`
- `CALL_V2_ROLLOUT_ALLOWLIST`

Rules:
- global `CALL_V2_ENABLED=false` overrides every mode
- percentage is integer 0–100
- percentage mode requires explicit non-empty salt
- allowlist mode requires a strict non-empty UID list
- no rollout configuration is exposed or logged

Trusted staff signal for caller:
`request.auth.token.callV2Staff === true`

For a staff-mode callee, use an injected Admin Auth lookup and require:
`customClaims.callV2Staff === true`

Never trust request data or a public user-profile field for rollout eligibility.

## Allowlist

Strictly parse a comma-separated server value:
- trim
- deduplicate exact UIDs
- reject malformed empty entries
- maximum 500 UIDs
- enforce existing UID format/length
- no wildcard, prefix, regex, email, or domain matching
- fail closed when invalid

## Percentage allocation

Create a pure helper, preferably `call_v2/rollout_gate_v2.js`.

Use SHA-256 over a canonical namespace/version + UID + salt. Map deterministically to `0..9999`. Eligibility is `bucket < percentage * 100`.

No `Math.random`, process-local state, unsafe conversion, or client-visible bucket/salt.

## Callable behavior

Authentication must be checked first.

`startCallV2` requires:
- global client switch enabled
- caller eligible
- callee eligible

Resolve callee eligibility before invoking the domain start service. Callee failure/ineligibility must produce no call, lock, command, idempotency, or outbox write.

Mode target resolution:
- `all`, `off`, `allowlist`, `percentage`: no Auth lookup
- `staff`: trusted Admin Auth lookup

Authenticated but ineligible start returns only:
- Firebase code `failed-precondition`
- details `{ callV2Code: "call_v2_not_enabled_for_user" }`

Do not reveal mode, reason, percentage, membership, claim, bucket, or salt.

For existing-call commands (`accept`, `decline`, `cancel`, `end`, media report, heartbeat): require authentication and global enabled, but do not re-check cohort. Existing calls must not be stranded by later rollout-policy changes.

Internal dispatcher, timeout endpoint, and scheduled recovery must not use the client rollout gate.

## Deployment validator

Extend readiness validation:
- both switches false remains valid without rollout values
- internal-only remains valid without rollout values
- client enabled with mode `off` is invalid
- staff mode requires explicit acknowledgement that staff claims are managed
- allowlist mode requires valid non-empty allowlist
- percentage mode requires 1–100 and explicit salt
- all mode requires explicit `allowGlobalClientRollout: true`

CLI may read rollout utility variables, but sanitized output may show only mode, percentage, and allowlist count—never UIDs or salt.

## Documentation

Create `docs/call-v2/PHASE_2K_ROLLOUT_GATING.md` covering:
- global switch vs rollout mode
- dual-party eligibility for new calls
- why existing calls are not re-gated
- staff custom claim
- deterministic buckets and salt rotation
- allowlist limits
- staged rollout and rollback
- no deployment and both switches still false

## Required validation

Keep all existing 197 tests passing and add focused tests for:
- all five modes
- exact staff boolean behavior
- strict allowlist parsing and max count
- deterministic buckets, 0/100 behavior, salt reshuffle
- auth-before-policy behavior
- generic ineligible error
- caller+callee eligibility before start service
- no target Auth lookup outside staff mode
- existing-call commands not re-gated
- validator safe/unsafe combinations and sanitized output
- internal task paths isolated from client rollout gating
- no production services contacted

Run with Node 20:

```bash
cd connect_functions
node --version
npm install
npm run check:call-v2
npm run validate:call-v2:deployment
npm run test:call-v2:emulator
npm run test:call-v2:emulator
npm run test:call-v2:emulator
node --check index.js
```

Run the explicit Firestore rules test script too. Do not run `firebase deploy`.

## Handoff

Write `docs/agent-loop/HANDOFF.md` with starting SHA, code commit SHA, branch-tip SHA when known, exact changed files, rollout behavior, validator changes, test totals and three run results, Node version, confirmations that switches remain false/no values invented/no production service contacted/nothing deployed, remaining risks, and Phase 2L recommendation.

Update `STATE.json` to `ready_for_review`, push `origin/call-v2`, and stop. Do not begin Phase 2L.