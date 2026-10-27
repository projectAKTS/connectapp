# Node.js 22 Functions Runtime Handoff

STATUS: `ready_for_review`

BRANCH: `call-v2` (known-good tags `stable-calls-oct-26` -> `46a71e9`,
`stable-calls-oct-27` -> `1e2d550`; untouched)
STARTING_SHA: `1e2d5503a2531e09abd2bcd1b6dc215330cb6ead`
AUTHORIZATION_SHA: `4bfd473`
IMPLEMENTATION_SHA: `e8eaf3d`
ENDING_SHA: `SELF`

## Change

- `firebase.json`: `runtime` changes from `nodejs20` to `nodejs22`.
- `connect_functions/package.json` and the root `engines` entry of
  `package-lock.json`: `node` changes from `20` to `22`.
- No dependency changes. `firebase-functions` stays at 5.1.1, because 6.x
  changes the root import.

## Deployed vs local source (read-only)

The 17 gen2 archives were downloaded from
`gcf-v2-sources-33757728932-us-central1`. The gen1 `onAuthUserCreated`
archive came from `generateDownloadUrl`. The archives represent five distinct
deploys:

| Archive | Functions | Deployed | Source match |
|---|---|---|---|
| A | 10 Stripe callables + `handleStripeWebhook`, `healthCheck`, `scheduledConsultationReminder` | 2026-03-04 | uncommitted |
| B | `getAgoraRtcToken` | 2026-04-19 | `2117d05` |
| C | `onCallInviteCreated`, `onCallInviteUpdated` | 2026-08-10 | `bd960d8` |
| D | `onChatMessageCreated` | 2026-05-17 | uncommitted |
| E | `callInviteTransition` | 2026-10-26 | `606a7a2` (= HEAD code) |
| F | `onAuthUserCreated` (gen1) | 2026-03-06 | uncommitted |

Comparison method:
- Every deployed export body was compared with local after whitespace
  normalization; all 18 are identical.
- Every top-level helper was compared, and each function was mapped to the
  differing helpers it calls.
- The only behavioral differences a redeploy ships:
  1. `scheduledConsultationReminder`: `getUserTokens` now resolves tokens via
     `getUserPushTokenSets`, which uses active `users/{uid}/pushInstallations`
     plus legacy user-doc tokens, excluding inactive ones. `sendToTokens` now
     logs FCM send failures. Both have been live for call pushes since
     2026-08-10.
  2. `onChatMessageCreated`: `getUserPushTokenSets` gains the same
     `pushInstallations` merge, so chat pushes resolve devices exactly like
     call pushes already do in production.
- All other functions (Stripe, Agora token, call invites, auth, health,
  `callInviteTransition`) have identical code paths.
- Packages: deployed A/B/D lack `@google-cloud/tasks`, `google-auth-library`
  and, for A, `agora-token`. These are used only by Call V2 or by the
  unchanged token path. Resolved `firebase-admin`, `firebase-functions`,
  `stripe`, `apn`, `@google-cloud/firestore` and `google-gax` are identical.
- Params: the local gitignored `.env.connectapp-278b4` was replaced with the
  copy deployed with C on 2026-08-10. The local copy differed only in six
  Call V2-only keys (deliberate `disabled` placeholders). Neither the old nor
  the new values are read by the 18 deployed functions. The previous local
  file was backed up to the session scratchpad.
- Gen1 F carries a legacy `.runtimeconfig.json`. No code reads
  `functions.config()`.

## Validation

- Under Node 22.20.0, `require('./index.js')` loads all 29 exports.
- Under Node 22.20.0, the `test/call_invites` tests pass 7/7 and the
  `test/call_v2` tests pass 87/87. The two emulator-only files are excluded,
  because Java is not installed; they fail identically on Node 20.19.5.
- Node 20.19.5 control: 87/87.
- The scoped dry run of exactly the 18 deployed names completed. Function
  resource references in the debug log are exactly those 18, with no Call V2
  function. The default compute service account lookup falls back to
  `33757728932-compute@`, the account all functions already run as.
- `git diff --check`: clean. The lockfile diff is limited to `engines`.

## Deploy (user runs it)

`firebase deploy --only functions:<18 names> --project connectapp-278b4`
with exactly the names above. Never run an unscoped functions deploy, which
would create 11 Call V2 functions.

## Deployment (2026-10-27)

The user ran the scoped 18-function deploy at about 04:55Z. Post-deploy
checks:
- `gcloud functions list`: all 18 report `nodejs22` and `ACTIVE`, including
  gen1 `onAuthUserCreated`. No Call V2 function exists.
- Every Cloud Run service passed its rollout startup probe.
- No ERROR logs since the deploy, and no `SetIamPolicy` calls. Invokers are
  unchanged: `handleStripeWebhook`, `callInviteTransition` and
  `getAgoraRtcToken` allow `allUsers`. `healthCheck` stays private, as before.
- Smoke checks: unauthenticated `callInviteTransition` returns 401, and an
  unsigned Stripe webhook returns 400, which means it is reachable and rejects
  the bad signature.
- The first scheduled `scheduledConsultationReminder` run on Node 22
  (04:59:04Z) returned 200 ("No consultations soon.").

## Risks

- The two token-resolution changes above.
- The FCM failure log includes full tokens. This already happens for call
  pushes; a later cleanup should log suffixes only.
- `firebase-functions` 5.1.1 is still outdated. Upgrading to 6.x is a separate
  task with breaking import changes.

PHYSICAL_FIX_CLAIM: `NONE` (runtime only; post-deploy check pending)
