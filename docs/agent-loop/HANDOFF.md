# Staging Deployment And Verification Handoff

STATUS: `ready_for_review` (reviewer: the founder; implemented by Claude)

BRANCH: `call-v2`
STARTING_SHA: `de0e1fb`
ENDING_SHA: `SELF`

Scope: the founder's approval to deploy to **`helperly-call-v2-dev` only**
and to verify it. Production was not deployed, read for data, or changed.
No payments were enabled. No legal text was published. Earlier rounds'
handoffs are in git history (`git log -- docs/agent-loop/HANDOFF.md`).

## Commits This Round

| SHA | What |
|---|---|
| `e82956c` | TTL index overrides list their default indexes (the CLI required it; behaviour unchanged) |
| `57cdced` | **Rules:** a first chat can open; chat, connection and consultation **lists** are allowed again; `tool/staging_smoke.mjs` |
| `6df4143` | **App:** deleting an account always signs out; the confirmation text no longer says messages are deleted (EN/FR) |
| `3a3d48b` | Staging iOS build is a release build and checks it is staging-only; docs |

## Deployed To Staging

- Firestore indexes and rules, Storage rules, hosting.
- **21 functions:** the 18 production functions plus `deleteAccount`,
  `processAccountDeletionRequests` and `onReviewCreated`. No Call V2
  function. The old `callV2RtcToken`, which held production Agora
  credentials, was deleted from staging.
- **Rules redeployed after the fix in `57cdced`.**
- **Isolation checks (verified):**
  - Agora is the staging test project (secret version 2);
  - `PAID_SESSIONS_ENABLED=false`, and Stripe uses a test key;
  - anonymous Firestore and Storage reads are denied;
  - the Android APK and the iOS app contain only the staging Firebase
    config.

## Bugs Found On Staging (Fixed)

1. **A first conversation could not open** ("Chat could not open"). The
   chat screen reads the chat before creating it, and the rule denied
   reading a chat that does not exist yet.
   - **Fix:** a person whose uid is in the chat id may read the missing
     chat (single-document read only).
2. **Conversation, connection and consultation lists were denied**
   ("No conversations yet" while a chat existed).
   - **Cause:** the list rules used `keys()` / `is list` checks that a
     query filter cannot prove. This is also true of the rules committed
     before this round.
   - **Not checked:** whether production's live rules have the same
     problem. Production was not read.
   - **Fix:** separate `list` rules written so the app's filters prove
     them. An unfiltered list is still denied (tested).
3. **After "Delete account", the deleted user stayed signed in**, on the
   onboarding screen.
   - **Cause:** the server removes the profile, so the root screen swaps
     to onboarding and closes Settings before the call returns. The
     confirmation and sign-out were tied to that closed screen.
   - **Risk:** the next app resume could have recreated an orphan
     profile.
   - **Fix:** sign out and confirm on the root navigator.
4. **The deletion confirmation said "messages will be deleted".** Wrong:
   messages stay with the people they were sent to, as documented. The
   text was corrected in EN and FR.

**Production impact:** fixes 1 to 3 should go into the next approved
production deploy (the rules, plus the app build for 3).

## Verification

**Server smoke test** (`node tool/staging_smoke.mjs`, disposable
`@example.test` accounts, deleted at the end): **21/21** after the rules
fix. It covers:
- 18+ enforcement;
- chat and the `notifiedAt` trigger;
- call invites;
- the staging Agora app id;
- payments, payouts and checkout refused;
- minor restrictions;
- private reports;
- `deleteAccount` with `complete: true`;
- name scrub;
- the deleted user cannot sign in.

**App on two Android emulators** (staging APK; Amira on A, Bilal on B):

| Area | Result |
|---|---|
| Sign-up, onboarding with the 18+ box, privacy prompt, discovery | PASS (before the rules fix) |
| First chat opens; message A→B written; `notifiedAt` set once; B gets the notification "Amira: …" | PASS |
| Conversation lists on both sides; profile "1 conversation"; My consultations opens without error | PASS |
| Reply B→A in real time | PASS |
| Audio call A→B: rings, accept, both join the staging Agora channel, A hangs up, B closes; invite `ended` | PASS |
| Video call B→A: both see and hear the other (emulator camera); B hangs up, A closes; invite `isVideo: true, ended` | PASS |
| Delete account (Bilal) | Server PASS: Auth user, profile and Storage gone; names scrubbed from 2 call records; messages kept with A. **App FAIL** (bug 3) |
| Delete account again with a fresh account, after the fix | PASS: "Account deleted" on the login screen, signed out, profile not recreated, Auth user gone |

**Automated:**
- Firestore rules: 31/31 (run serially; these include the new list and
  first-chat tests);
- Storage rules: 5/5;
- Node: 63/63;
- Flutter `test/i18n` and `test/mvp`: 73/73;
- `flutter analyze lib`: no issues.

## Not Tested Yet

- **iPhone:** CallKit, VoIP while killed or locked, APNs alerts, iOS
  permissions.
- **Real audio quality:** emulators prove connection and media flow,
  not quality.
- **Report and block from the app UI.** The server side is covered by
  the smoke test.
- **Password reset emails (EN/FR):** need the founder's alias.
- **French UI on staging:** French was checked earlier on emulators
  against production.
- **18+ in the UI:** the checkbox was seen. Continue without it was not
  retried on staging; the server rule is verified.

## Founder Actions

1. **Optional:** disable the old staging Agora secret version 1. The
   permission classifier blocked me from doing it.
   ```bash
   gcloud secrets versions disable 1 --secret=AGORA_APP_ID --project helperly-call-v2-dev
   gcloud secrets versions disable 1 --secret=AGORA_APP_CERTIFICATE --project helperly-call-v2-dev
   ```
2. **APNs on staging:**
   - The four staging `APNS_*` secrets were placeholders, so iPhone VoIP
     calls could not have rung on staging.
   - The founder copied production's Apple key into the staging secrets.
     The key belongs to the Apple account and is the same bundle;
     production was unchanged.
   - Claude redeployed `onCallInviteCreated`, `onCallInviteUpdated` and
     `onChatMessageCreated` to staging.
   - **Remaining:** upload the same `.p8` in Firebase console > Project
     settings > Cloud Messaging > Apple app, for chat alerts.

## Next Steps: Physical iPhone

1. Connect the iPhone by cable, unlock it, and keep it unlocked.
2. Build (already built once, 2026-11-01): `tool/build_staging.sh ios`.
   It must print `iOS app config: helperly-call-v2-dev only`.
3. Install. This replaces the TestFlight app (same bundle id):
   ```bash
   xcrun devicectl list devices
   xcrun devicectl device install app --device <iPhone id> build/ios/iphoneos/Runner.app
   ```
4. Open the app and sign up a new account (`+hb-a` alias). Allow
   notifications, microphone and camera.
5. On an emulator or a second phone with the staging APK, sign up `+hb-b`.
   Then run `docs/BETA_MANUAL_TESTS.md` rows 1 to 16.
   - **Call checks:** iPhone unlocked, then locked, then with the app
     killed. Expect the CallKit screen each time.
   - **If calls arrive only as an ordinary notification:** delete the
     app and reinstall it. iOS stops delivering VoIP pushes after crashes.
6. Afterwards, reinstall the production app from TestFlight.

## iPhone Round (2026-11-02, staging build on the founder's iPhone 16 Pro Max)

Founder on the iPhone (`yakupusamea+hb-a@gmail.com`); Amira on emulator A.

| Check | Result |
|---|---|
| Sign in with email/password; discovery (Amira finds the iPhone helper: Housing search, FR/EN) | PASS |
| Push registration (FCM, APNs, VoIP tokens) | PASS |
| Audio call, app open | PASS. Connected; audio both ways; ended from the iPhone, Amira's side closed. iOS shows the call as a top banner while the phone is in use (standard CallKit, as in WhatsApp) |
| Audio call, phone locked | PASS. CallKit screen (name, slide to answer) |
| Audio call, app killed and phone locked | PASS. CallKit; answered in 10 s |
| Video call | PASS. Video both ways; ended from Amira, the iPhone closed |
| Chat notification, phone locked | PASS |
| Tap a chat notification (app in background, or killed) | PASS after fix `1b51316` |
| Notifications per message, app open | PASS after fix `9a3aa60`: 1 banner (was 3 on iPhone, 2 on Android) |
| Sign in with Apple | Not available on staging (only email/password is enabled). Production not checked |

**Fixes:**
- `1b51316`: tapping a chat notification did nothing when that chat was
  still open under another screen (for example after a call).
  - Reproduced on Android.
  - A test now covers it; it fails without the fix.
- `9a3aa60`: the Firestore chat listener added its own "New Message"
  banners next to the push, and announced old chats on every app start.
  - It is now silent once the FCM token is saved.
  - Its first snapshot no longer notifies.

**Staging APNs:**
- The `APNS_*` secrets were placeholders. The founder copied production's
  Apple key; the key is account-level and the bundle is the same.
- The `.p8` was uploaded in the console for development and production.

**Tooling:**
- `tool/build_staging.sh` passes extra build arguments through.
- `--dart-define=ENABLE_RUNTIME_DIAG=true` writes push stages to the user
  document, which can be polled.
- Use it only for a short diagnosis: on iOS it caused a write loop of
  about one write per second on the user document. The normal build was
  measured at 1 write per minute.
- `flutter run` / `attach` to the iPhone did not keep a log connection
  (local Flutter 3.32.1, iOS 26).

**Automated:**
- full Flutter suite: 2516 passed, 16 failed (the 16 known failures);
- `flutter analyze`: clean.

**The founder's iPhone has the staging build.** Reinstall the production
app from TestFlight when testing is done.

**Security follow-up:** the APNs private key was shown in an editor
selection that was sent in this session. Rotate it before the public
launch:
1. Create a new APNs key in Apple Developer.
2. Set it in the production and staging `APNS_*` secrets and in both
   Firebase consoles.
3. Revoke the old key.

## APNs Key Rotation (2026-11-02, in progress)

- **New key:** `A55R9GWWX2`, Sandbox & Production, created by the founder.
  - A first key, `T6YPJ6FCWH`, was Sandbox-only: Apple answered
    `BadEnvironmentKeyInToken` for production. It was replaced.
- **Verified against Apple:** with a dummy token, both environments answer
  `BadDeviceToken`, which means the key is accepted. The check was run on
  the downloaded file and on the stored secrets of both projects.
- **Secret Manager:** the founder added the new `APNS_KEY_ID` and
  `APNS_VOIP_KEY_P8` versions:
  - staging: version 3;
  - production: version 7.
- **Staging:**
  - `onCallInviteCreated`, `onCallInviteUpdated` and `onChatMessageCreated`
    redeployed; they use version 3;
  - the founder replaced the key in the staging console (development and
    production);
  - not yet exercised on a device.
- **Production:**
  - functions still use version 6, the old key, which still works;
  - the console still has the old key.
- **Remaining, with the approved production deploy:**
  1. Redeploy the three functions.
  2. Upload `A55R9GWWX2` in the production console.
  3. Test a call and a chat push on TestFlight.
  4. Only then revoke `AJDC73P524` in Apple Developer.
- **Key file:** the founder keeps the `.p8` in a safe place until step 2,
  then deletes it.
