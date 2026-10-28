# Android Release Readiness Handoff

STATUS: `ready_for_review` (reviewer: Claude, per the user's delegation)

BRANCH: `call-v2`
STARTING_SHA: `38bbd25`
AUTHORIZATION_SHA: `f4c72f8`
IMPLEMENTATION_SHA: `3ae2314` (package id, label), `c65e9ab` (permission fix, diagnostic)
ENDING_SHA: `SELF`

## Findings

1. **The release build works without shrink fixes.** It was never built
   before this task.
   - The R8 release APK (`minifyEnabled true`, existing keep rules) passed
     the call matrix under the old package first.
   - No `ClassNotFoundException`, `NoSuchMethod` or missing-plugin errors.
   - `proguard-rules.pro` is unchanged.
2. **Android never asked for notification permission.** Found on the first
   clean install under the new package.
   - Evidence: `POST_NOTIFICATIONS: granted=false` with no `USER_SET` flag.
   - Cause: `NotificationService.initialize` asked only on
     `notDetermined`. firebase_messaging on Android reports a missing grant
     as `denied`.
   - Impact: a fresh install could never ring from the background unless
     the user enabled notifications in Settings. Earlier emulator runs
     passed only because `install -r` kept an old grant.
   - Fixed. The task was amended for this.
3. **The app label was `connect_app`,** shown in the system permission
   prompts. It is now `Helperly`, the iOS display name.
4. **Microphone and camera are asked on the first call** (runtime
   permissions, unchanged).
   - Verified manually on the emulator: B answered from the background,
     the mic prompt appeared, and B connected ~10 s after "While using
     the app".
   - Automated runs pre-grant mic and camera (`pm grant`), the same state
     as a user who already allowed them.
5. **Killed-app answer is slow:** ~20 s from the Accept tap to the Agora
   join on the release build, on an overloaded host (load ~6-8, swap
   17/18 GB).
   - Activity shown: +1.7 s.
   - Dart handles the accept (`accept_tap`): +10.6 s. App startup is the
     largest share.
   - Server accept: +16.3 s. One `callInviteTransition` HTTPS call took
     5.7 s.
   - Agora join: +20.4 s.
   - The next-task candidate is below.

## Changes

- **Package id** `com.yakup.helperly`:
  - `namespace`/`applicationId`, the manifest `package`, and MainActivity
    moved to `kotlin/com/yakup/helperly`.
  - `firebase_options.dart` android `appId`
    `1:33757728932:android:2cc74206f093c5979a1631`.
  - `google-services.json` now holds both Android clients.
- **Firebase** (CLI, approved by the user):
  - New Android app "Helperly Android" for `com.yakup.helperly`, with the
    debug signing key's SHA-1/SHA-256.
  - The old `com.example.connect_app` app is untouched.
- **`notification_service.dart`:**
  - New `shouldRequestNotificationPermission` (pure, tested): also asks on
    Android `denied` in the foreground. iOS is unchanged. Android itself
    stops prompting after two denials.
  - New startup diagnostic `android_call_permissions`
    (`notificationsAllowed`, `fullScreenIntent`).
- **Manifest:** `android:label="Helperly"`.

## Validation

- **Builds:** `flutter build apk --release` succeeds for both packages
  (269.6 MB, all ABIs).
- **Release E2E, old package** (before the rename; permissions granted
  earlier):
  - matrix 6/6, with killed answer rerun 2/2 after the harness kill fix;
  - foreground audio and video PASS.
- **Release E2E, `com.yakup.helperly`** (fresh install, re-login,
  notification prompt answered "Allow", mic and camera granted):
  - Single-device background/killed × answer/decline/cancel: 6/6,
    `plainFcmNotifications=0`.
  - Foreground audio: PASS (accept to connected 2.9 s, Agora join
    170-205 ms). Foreground video: PASS.
  - Multi-device, other silent after Accept:

| Other device | Answered on | Other silent |
|---|---|---|
| killed C | B | 2.5 s |
| killed B | C | 2.5 s |
| background C | B | 3.9 s |
| background B | C | 3.3 s |
| foreground C | B | 4.1 s |
| foreground B | C | 4.6 s |

  - Every multi-device run held the call for 10 s, and every device was
    idle afterwards.
- **Permission paths:**
  - Notification prompt "Don't allow": the diagnostic shows
    `notificationsAllowed: false`, and the next launch asks again.
  - Full-screen intent denied (`appops ... deny`): the diagnostic shows
    `fullScreenIntent: false`. A killed-app call still showed the call
    notification, was answered and connected. The permission was restored
    afterwards.
- **Dart:**
  - `test/android/notification_permission_test.dart` 3/3. RED: with the
    Android branch removed, 1 test fails.
  - `test/android` + `test/multi_device`: 19/19.
  - Full `flutter test --timeout 120s`: +2422 -16. 2 are the pre-existing `call_message_stability_test.dart` failures; 14 are the working-tree guards (uncommitted agent-loop docs). 2438 tests = 2435 + 3 new.
  - `flutter analyze lib test integration_test`: no issues.
- `git diff --check`: clean.
- **Harness** (local, git-excluded): `kill_app.sh` (release builds are not
  debuggable, so `run-as` fails; a run now fails if the process survives),
  `login.sh`, `release_e2e.sh`, `HELPERLY_PKG`, and a `ui.sh` crash fix.

## Known Gaps And Next-Task Candidates

1. **Killed-app answer latency (~20 s).**
   - Process the plugin accept earlier in startup, instead of after the
     full `NotificationService.initialize`.
   - Measure and reduce the first `callInviteTransition` HTTPS latency
     (cold function, token fetch).
   - Recommended as step 6, after the physical check.
2. **Physical Android:** not run. Step 5 needs the user's approval and the
   phone.
   - Includes answering from the lock screen and the first-call mic prompt
     over the lock screen.
3. **Sideload only:** the release is signed with the debug key. A Play
   upload key and store listing are separate decisions.
4. **Play policy:** apps installed from Play get the full-screen intent
   only if Play accepts them as calling apps. The fallback (call
   notification) works, as verified above.
5. **App Check:** Android uses Play Integrity. Sideloaded builds cannot
   attest, so features that require App Check tokens (consultation
   booking, payments) may fail on sideloaded phones. Calls do not use App
   Check.
6. **Stale installations:** the old-package installation documents on the
   emulators stay `active: true`. Sends to them fail as unregistered; the
   server does not prune them.
7. **Host memory:** 3 emulators plus a Gradle daemon exhaust swap. Stop
   Gradle (`./gradlew --stop`) after builds.

PHYSICAL_FIX_CLAIM: `NONE` (Android emulators only)
