# HTTPS Call-Invite Signaling Handoff

STATUS: `ready_for_review`

BRANCH: `call-v2-https-signaling` (locked baseline: `stable/calls-oct-26`,
tag `stable-calls-oct-26` -> `46a71e9`)
STARTING_SHA: `46a71e94aa17e26478a929ab71b786a9f83312d2`
AUTHORIZATION_SHA: `da33314`
IMPLEMENTATION_SHA: `606a7a2808bfd629c440d911eb442b4060e2c672`
ENDING_SHA: `SELF`

## Why

Firebase iOS 11.10.0 can wedge Firestore's only worker queue on a
connectivity change (`GrpcStream::Shutdown` -> unbounded `WaitUntilOffQueue`,
firebase-ios-sdk#12522). `3db9e00` removed the app-side trigger, but every
call-critical state change was still a client Firestore transaction and
several had no timeout, so a wedge made accepted calls unable to connect and
an unfinished teardown blocked the next call (physical failure 2026-10-26).

## Changes

- `connect_functions/call_invites/call_invite_transition.js` + export
  `callInviteTransition` (us-central1): actions `accept`, `decline`,
  `terminal`, `stage` mirroring the client transactions exactly; the actor
  role comes from the authenticated uid; only allowlisted fields and server
  timestamps are written; repeats are idempotent; invalid ids and reasons
  are rejected.
- `lib/services/call_invite_signaling.dart`: HTTPS client with a 6 s
  timeout; any failure returns null.
- `CallSessionManager`: accept, decline, media stages, and terminal
  transitions try HTTPS first and fall back to the existing Firestore
  transaction, now bounded to 8 s; `_setInviteStatusIfCurrent` is bounded
  too. Test runtimes keep the Firestore path unless a fake is injected.
- `lib/main.dart`: App Check uses `AppleProvider.deviceCheck`. Read-only
  check: App Attest has no entitlement and no Firebase key, DeviceCheck has a
  key, and no service enforces App Check; the device log shows an App Attest
  assertion followed by a 403 before every call.

## RED / GREEN

`test/call_v2/real_flow/call_v2_https_signaling_test.dart` (identical file),
baseline `da33314` + seams only (interface file, ignored `configure` param):
0/3 - `Expected: ['invite_b'] Actual: []` (accept hangs on wedged
transactions); `operation did not complete within 30s simulated time`
(teardown awaits a wedged transaction forever); no HTTPS attempt. After the
change: 3/3.

## Validation

- Server: `node --test test/call_invites/*.test.js` 7/7; existing
  `test/call_v2` 87/88 (the remaining file requires the Firestore emulator;
  Java is not installed, so emulator tests did not run).
- Entire Flutter `test/` folder on a clean checkout of the implementation
  SHA: 2,417 passed, 2 failed (`HELPERLY_TEST_MODE` integration wrappers,
  identical on the baseline). A first run hit a host stall (6 load failures,
  no assertion failures); the rerun was clean.
- iOS RunnerTests (iOS 26.0): 31 passed.
- `flutter analyze`: no issues. Format and `git diff --check`: clean.
  Dependencies/lockfiles: unchanged.

## Deployment

The user deployed `callInviteTransition` (2026-10-26) with
`firebase deploy --only functions:callInviteTransition --project
connectapp-278b4`, using a local, gitignored `.env.connectapp-278b4` holding
only non-secret params at their code defaults (Call V2 stays disabled).
`functions:list` shows it in us-central1 (nodejs20) beside the unchanged
existing functions. An unauthenticated smoke call returned HTTP 401
`UNAUTHENTICATED` ("Sign in is required.") and wrote nothing.

TestFlight 1.0.2 (202610261913), source `a46f187`, uploaded (IPA SHA-256
`634929254609187c49881bda0121c4ab4be3bb7e745b605c56e515772acb5224`); commit
marker verified in archive and IPA.

## Physical verification (2026-10-27)

The user tested build 202610261913 on two iPhones and reported that every
call passed: three audio calls in a row, then a video call. A further call
with the callee on cellular instead of Wi-Fi also passed.

Read-only server corroboration (`firebase functions:log --only
callInviteTransition`):
- 40 authenticated callable requests between 01:29:22Z and 01:30:15Z, each
  with `auth: VALID`, `app: VALID`. The HTTPS path served real call
  transitions, and App Check tokens from DeviceCheck now verify.
- No warnings or errors.
- The only other request is the earlier unauthenticated smoke call.

The CLI output may be truncated, because it returned only 88 lines. Per-call
client logs were not collected.

## Risks

- Google decommissions the Node.js 20 runtime on 2026-10-30; after that no
  function can be deployed until `runtime`/`engines` move to Node 22 and are
  verified. `firebase-functions` 5.1.1 is also flagged as outdated.
- The callable is unenforced by App Check (like `getAgoraRtcToken`).
- The underlying SDK wedge is mitigated, not fixed. Reads that depend on the
  Firestore client still degrade to their timeouts.
- Physical coverage is one session: 4 calls plus 1 call on cellular. It
  does not prove reliability under long sessions, poor networks, or
  background/locked-screen accept, where native `syncInviteStatus` still uses
  a Firestore transaction.

PHYSICAL_FIX_CLAIM: `USER_VERIFIED_SESSION` (scope above; no reliability
guarantee)
