# Answered Elsewhere (Multi-Device Callee) Handoff

STATUS: `ready_for_review`

BRANCH: `call-v2`
STARTING_SHA: `d7f208b`
AUTHORIZATION_SHA: `afa2b26`
IMPLEMENTATION_SHA: `50766c4`
FIX_SHAS: `8c2d0ee` (capability targeting), `f271b20` (Firestore rule)
ENDING_SHA: `SELF`

The user chose to start this task before the step-2 review. Please review
step 2 (`11d46e0`, handoff `d7f208b`; Android full-screen incoming call) and
this task together.

## Root cause (verified in source)

1. `planAccept` recorded only `status: accepted`. A second device of the
   same callee got `alreadyAccepted` and could join.
2. No push on `ringing -> accepted`. `_handleIncomingInviteSnapshot` ignored
   non-ringing, non-terminal statuses. The other device kept ringing and
   kept its lifecycle reservation: the iPhone `busy_active_call`.
3. `handleSystemEndedInvite` without a local session wrote `ended` for
   `accepted`/`joining`/`connected`. Ending the other device's native UI
   would therefore have ended the live call on the answering device. Any
   "stop ringing" fix had to block this first.

## Changes

### Server (`50766c4`, `8c2d0ee`)

- `call_invite_transition.js`:
  - `accept` takes an optional `installationId`; invalid values are
    ignored.
  - On `ringing`, accept writes `acceptedInstallationId`. A different
    installation later gets the new decision `acceptedElsewhere`, with no
    write.
  - Callee `terminal`/`stage` from a different installation:
    `writeApplied:false` / `applied:false`, `reason: answered_elsewhere`.
  - The caller and id-less (old) clients are never fenced.
- `answered_elsewhere.js` (new): pure helpers.
  - The qualifying transition is `ringing -> accepted` with an answering id.
  - Targets (`8c2d0ee`): only active `pushInstallations` with
    `answeredElsewhereV1: true`. The answering installation and every
    token value it holds are excluded. Legacy user-document tokens are
    never used.
  - Payload: the existing `call_end` shape with `status:
    answered_elsewhere` and `acceptedInstallationId`.
- `index.js` `onCallInviteUpdated`: the new accepted branch sends VoIP +
  FCM data to those installations and logs counts only. No answering id
  means no push. Terminal pushes are unchanged.

Why `8c2d0ee`: found before handoff. An old build, for example today's
TestFlight iPhone, ends its CallKit call natively on any `call_end` VoIP
push. Its old Dart `handleSystemEndedInvite` would then write `ended` (root
cause 3) and end the call that Android answered. New builds write the
capability flag; old builds never get this push.

### Firestore rules (`f271b20`, scope amended with user approval)

- `validPushInstallationData` listed the allowed keys with `hasOnly`, so
  the new flag made every `pushInstallations` upsert from new builds fail.
  - The server then found no capable installation (`fcmCount: 0`).
  - A killed second device rang until timeout (~36 s).
  - The installation's token/`lastSeenAt` refresh also stopped for new
    builds.
- The rule now allows `answeredElsewhereV1` as an optional bool. Old
  builds never write it, so they are unaffected.
- Found by the emulator E2E rerun, not by unit tests: the foreground and
  background paths dismiss via the Firestore listener and hid it. The
  harness `multi.sh` now requires dismissal within 15 s of Accept, so a
  ring timeout no longer counts as PASS.

### Client (`50766c4`, `8c2d0ee`)

- `push_installation_id.dart` (new): the existing id file
  (`helperly_push_installation_id`), shared with the background isolate.
  NotificationService delegates to it.
- `CallSessionManager`:
  - **Installation id:** set once at startup through `setInstallationId`;
    call paths never await storage.
    - Accept, terminal and stage requests carry the id.
    - The Firestore fallback accept writes `acceptedInstallationId` and
      returns `acceptedElsewhere`.
  - **Dismissal:** one idempotent path, `handleAnsweredElsewhere`, that
    marks the invite first and then reuses the write-free
    `_terminalizeUnacceptedIncomingInvite`.
    - Triggers: a listener snapshot, the push, and the `acceptedElsewhere`
      decision.
    - It is a no-op while this device is accepting (`_acceptsInFlight`),
      holds a session, or has a pending accepted intent.
  - **Guards:**
    - `handleSystemEndedInvite`, `handleSystemTimeoutInvite` and
      `declineInvite` skip marked invites.
    - The no-session `ended` write is skipped inside its transaction when
      another installation answered.
    - A single-device CallKit end before the session exists still ends the
      call.
- `notification_service.dart`:
  - `call_end` + `answered_elsewhere` addressed to the own installation is
    ignored. Otherwise it goes to the manager.
  - The installation upsert writes `answeredElsewhereV1: true`
    (`8c2d0ee`).
- `android_incoming_call.dart` + background handler: `answered_elsewhere`
  for the own installation is ignored (`answered_here`). Otherwise the
  plugin UI is ended.
- `AppDelegate.swift`: in the terminal PushKit branch, `answered_elsewhere`
  is ignored when this device accepted that CallKit id (ledger
  `accepted`/`active` or the stored accepted id). Every other terminal push
  is unchanged.

## Validation

- **Server:** `node --test test/call_invites/*.test.js` on Node 22.20.0:
  19/19.
  - Covers accept ids, `acceptedElsewhere`, fencing, old-client
    compatibility, capability targeting (old build, inactive device,
    shared token), and the payload.
- **Rules:** `npm run test:call-v2:rules` (local emulator, demo project):
  10/10.
  - RED first: the new flag test failed against the old rule (9/10).
- **Dart:**
  - `test/multi_device/` 5/5 and `test/android/` 11/11 (16/16 at
    `f271b20`; stable across 3 earlier runs).
  - RED check: with `_answeredByOtherInstallation` forced to `false`,
    2 multi-device tests fail.
- **Full `flutter test --timeout 120s` at `8c2d0ee`:** +2419 -16.
  - 2 are the pre-existing HELPERLY_TEST_MODE failures in
    `call_message_stability_test.dart`.
  - The other 14 are the working-tree guards (`git diff HEAD` with
    uncommitted agent-loop docs).
  - `f271b20` changes no Dart file. The 71 Dart test files that read
    `firestore.rules` were rerun: +712 -14, the same 14 guards only.
- **`flutter analyze lib test integration_test`:** no issues.
  - A bare `flutter analyze` also scans the user's local, git-excluded
    `test_artifacts/` evidence copies.
- **iOS:** `RunnerTests` on the iPhone 17 Pro simulator: `TEST SUCCEEDED`
  (at `50766c4`). No native change since.
- `git diff --check`: clean.

### Deploys (run by the user, verified by Claude)

- 2026-10-28 ~02:04Z: `callInviteTransition`, `onCallInviteUpdated`,
  `onCallInviteCreated` at `50766c4`.
- After `8c2d0ee`: `onCallInviteUpdated` only.
  - Its deployed gen2 source is byte-identical to `8c2d0ee` (`index.js`,
    `answered_elsewhere.js`, `call_invite_transition.js`).
- 2026-10-28 07:11:37Z: `firestore:rules` only.
  - Before the deploy, the live ruleset equalled `HEAD`'s.
  - After it, the live ruleset is byte-identical to `f271b20`.
- No other function, index or setting was changed.

### Emulator E2E

3 Android 16 emulators. A = Baris (caller); B and C = venus on two devices.
"Silent" is measured from the Accept tap.

After the rules deploy (`f271b20` live):

| Other device | Answered on | Other silent | Path |
|---|---|---|---|
| killed C | B | 11.1 s | FCM push to background isolate; server `fcmCount: 1` |
| killed B | C | 9.9 s | FCM push |
| background C | B | 2.7 s | Firestore listener |
| background B | C | 4.0 s | Firestore listener |

Before the rules deploy (`8c2d0ee` server):

| Other device | Answered on | Other silent |
|---|---|---|
| foreground C | B | 5.1 s |
| foreground B | C | 11.8 s |
| background C | B | 2.7 s |
| background B | C | 11.3 s |
| killed (both directions) | | ~36 s: ring timeout. This is the rules bug above |

- Every run: the call stayed connected for 10 s and all devices were idle
  after hang-up.
- Both devices rang for the next call, so there was never a busy decline.
- Accept to server accept: 0.7–3.7 s. The host was swapping heavily with
  3 emulators, so latencies are higher than in the first round (`50766c4`:
  2.6–3.5 s, including the killed path).

### Single-device regression (C stopped)

- Foreground audio, callee and caller ending: PASS. Agora join 244–423 ms;
  no fallbacks.
- Earlier, at `50766c4`:
  - foreground video: PASS;
  - background/killed × answer/decline/cancel: 6/6, with
    `plainFcmNotifications=0` (also verifies step 2's server change is
    live).

## Known gaps

1. No physical iOS verification. iOS has native + Dart changes and needs a
   TestFlight build, which needs the user's approval.
   - Until then, physical iPhones run old code. They write no capability
     flag and send no installation id, so they never get the
     answered-elsewhere push.
   - When another device answers, an old iPhone keeps ringing until
     timeout and stays reserved meanwhile. This is today's behavior, but
     it can no longer end the answered call.
2. If an accept happens before the startup id read completes (cold start),
   it carries no id and keeps the old behavior for that call.
3. On the killed path, dismissal took ~10 s under heavy host load. That is
   FCM delivery plus a cold background isolate. Not measured on physical
   Android.
4. Repeated VoIP pushes to an iPhone that is not showing that call follow
   the existing terminal-push pattern. PushKit's report-a-call policy risk
   is unchanged by this task.
5. Host memory: 3 emulators exhaust swap. Emulator B crashed once and was
   restarted with 1.5 GB RAM.

PHYSICAL_FIX_CLAIM: `NONE` (Android emulators only; physical iOS and
physical Android pending)
