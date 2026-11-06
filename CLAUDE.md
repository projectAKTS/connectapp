# Helperly: Project Context For Claude Code

**Helperly** is a Flutter and Firebase app for peer help: people who have
been through something (housing, jobs, school, settling in Québec) help
people going through it now. Help happens by chat and by audio or video
call (Agora).

- **Stage:** a small, free, invite-only beta in Montréal. The app is in
  English and French.
- **Founder:** Yakup, the only human on the project. Reply to him **in
  Turkish**, in short, plain language. He is not a developer.
- **Your role:** CTO and engineer. Make the engineering and UX decisions
  yourself, in the style of WhatsApp. Ask the founder only about money,
  legal matters, production data, or anything irreversible.

## Where Things Are

| Thing | Value |
|---|---|
| Repo | `github.com/projectAKTS/connectapp`. Work on branch **`call-v2`** (`main` is old) |
| Safe restore point | Tag `safe-mvp-beta-2026-11-04` and branch `stable/mvp-beta-2026-11-04` (commit `da520af`). Older: tag `stable-calls-oct-26`. Never move or delete these |
| App code | `lib/` (Flutter 3.35.4 in CI; this Mac has 3.32.1) |
| Backend | `connect_functions/` (Cloud Functions v2, Node 22) |
| Rules | `firestore.rules`, `storage.rules`. Indexes: `firestore.indexes.json` (staging); **production uses `deploy/production/firestore.indexes.json`** |
| Docs | `docs/`. Start with `docs/PRODUCTION_DEPLOY_PLAN.md`, `docs/SAFETY_ROADMAP.md`, `docs/BETA_OPS_CHECKLIST.md`, `docs/agent-loop/HANDOFF.md` |
| Memory | `~/.claude/projects/-Users-yakup-connectapp/memory/` (loaded automatically) |

## Two Firebase Projects: Read Before Any Command

| | Production | Staging |
|---|---|---|
| Project id | `connectapp-278b4` | `helperly-call-v2-dev` |
| Data | Real accounts. The founder says they are all test accounts, but **treat them as real** | Disposable `@example.test` accounts |
| Who deploys | **The founder**, from Terminal. Claude's permission system blocks most production deploys and writes | Claude, freely |

- `.firebaserc` default alias is **production**. Always pass `--project`
  explicitly. Never run a bare `firebase deploy`.
- **Never deploy functions unscoped** (`--only functions`): that would
  also deploy the 11 Call V2 functions, which must stay off. Always list
  the functions one by one (`functions:a,functions:b`).
- **Never deploy production `hosting`** until the founder decides. It
  would publish the Terms, the privacy policy and the delete-account page
  for the first time, and they still use the placeholder
  `support@helperly.app`. **`helperly.app` belongs to another company**
  (a family-activities app with live Google mail, checked 2026-11-05);
  `helperly.ca` and `helperly.com` are also taken, and the App Store
  (CA/US) already lists "Helperly App", "Helperly User" and "Helperly
  Provider" from others. "Helperly" is a working name; the founder wants
  a global (non-French) brand. Candidates checked 2026-11-05: Peerway
  (`peerway.app`, `getpeerway.com` free), Beenthru (`beenthru.app`). The placeholder is
  also in the app (`lib/config/legal_texts.dart`, the age-restricted
  screen), so mail written to it reaches that company: replace it before
  any tester beyond the team.
- **Never deploy the main `firestore.indexes.json` to production.** It
  holds Call V2 TTL policies (automatic, irreversible deletion) and lacks
  production's 6 feed indexes. Use:
  ```bash
  firebase deploy --only firestore:indexes --config firebase.production-indexes.json --project connectapp-278b4
  ```
- `.claude/settings.local.json` allows exactly three production commands.
  Anything else the founder runs:
  - the indexes command above;
  - `firestore:rules,storage,hosting` (do not use it while hosting is held);
  - `functions:processAccountDeletionRequests`.

## Hard Rules

- No production deploy without the founder's go-ahead for that change. He
  runs it, or you run an allowed command.
- No modifying or deleting production data, except changes he explicitly
  approves (for example `tool/backfill_replied_by.mjs --apply`, which he
  ran himself).
- Payments are **off**:
  - `PAID_SESSIONS_ENABLED=false` in `connect_functions/.env.*`;
  - never real Stripe charges;
  - never production Stripe or Agora credentials in staging.
- **Never print secrets.** That covers `.env` values, `.p8` contents,
  tokens and `test_artifacts/secrets/test_logins.txt`. Check secrets with
  booleans or lengths only. **Never open a `.p8` in an editor:** a
  selection reaches the AI context (this happened once and is in
  `docs/legal-drafts/INCIDENT_REGISTER.md`).
- Do not commit `pubspec.lock` or `ios/Podfile.lock`.
- Do not touch the untracked `.aider*` files or
  `docs/CALL_V2_ARCHITECTURE_DEEP_DIVE.md`.
- Never `git reset --hard`, `git clean` or force-push. Do not move the
  stable tags.
- **Never call Baris's iPhone** (a real person). Do not email real users.
  Password resets go only to the founder's own Gmail aliases
  (`yakupusamea+hb-…@gmail.com`).
- Do not publish legal documents. Drafts live in `docs/legal-drafts/`.
- When something you try is denied by the permission system, **do not
  work around it**. Give the founder the exact command and say why.

## What Is Live In Production (2026-11-05)

- **Functions (23):** the 18 original ones plus `deleteAccount`,
  `processAccountDeletionRequests`, `onReviewCreated`, `onReportCreated`
  and `onPostImagesChanged`. No Call V2 functions.
- **Rules:** current `firestore.rules` and `storage.rules` (identical to
  `call-v2`).
- **Indexes:** production's 6 composite indexes plus the comment and reply
  collection-group overrides. No TTL.
- **APNs:** key `A55R9GWWX2`, secret version 7, also uploaded in both
  Firebase consoles. The old key `AJDC73P524` is **revoked**.
- **iOS:** TestFlight 1.0.2 (`202611040659`), with legacy calls (no Call
  V2 flags). Build and upload:
  ```bash
  BN=$(date +%Y%m%d%H%M)
  flutter build ipa --release --build-number=$BN --dart-define=CALL_V2_BUILD_COMMIT=$(git rev-parse --short HEAD)
  xcodebuild -exportArchive -archivePath build/ios/archive/Runner.xcarchive \
    -exportOptionsPlist <app-store-connect upload plist, team 3UDYS4KQW3> -allowProvisioningUpdates
  ```
- **Backup:** `gs://connectapp-278b4-backups/2026-11-02-pre-mvp-deploy/`.
- **Google Cloud Vision** is enabled in both projects, for post photo
  checks.

## Features And Where The Code Is

| Feature | Code | Notes |
|---|---|---|
| 18+ declaration; minors restricted | `lib/models/age_policy.dart`; rules `callerAgeAllowed`, `notRestrictedMinor` | Every account declares once |
| Account deletion | `connect_functions/account/delete_account.js`, `lib/screens/settings/settings_screen.dart` | Signs out on the root navigator; failed cleanup is retried daily |
| Chats, push and calls (legacy V1) | `lib/screens/chat/chat_screen.dart`, `lib/services/notification_service.dart`, `lib/services/call_session_manager.dart`, `onChatMessageCreated`, `onCallInvite*` | **Call screens are fragile**: change them only with a full call retest on the iPhone (unlocked, locked, killed) |
| First-contact safety | rules `otherHasWritten`, `calleeAcceptsCall`; `connect_functions/chat/replied_by.js`; `tool/backfill_replied_by.mjs` | Until the other person writes: text without links only; non-helpers cannot be called. `repliedBy` is server-only |
| Safety banner, scam warning | `lib/screens/chat/chat_screen.dart` (`_ChatSafetyBanner`), `lib/services/scam_signals.dart` | On-device only |
| Blurred media | `lib/widgets/sensitive_media_cover.dart` | Received chat photos; posts marked `sensitive` |
| Reports and blocks | `lib/services/safety_service.dart`; `onReportCreated` (`connect_functions/safety/report_threshold.js`) | Reporter's hidden list in `users/{uid}/private/safety` (owner-only). 2 open reports set `hiddenByReports` |
| Post photo check | `onPostImagesChanged` (`connect_functions/safety/image_safety.js`) | Sets `imageSafety`, `sensitive`, `hiddenBySafety`. Chat media is never sent to Vision |
| i18n | `lib/l10n/*.arb` (EN template, FR), `gen_l10n`, `context.l10n` | Stored values are English ids; the guard test forbids hard-coded UI strings |

To restore a hidden post: close its reports and remove `hiddenByReports`
or `hiddenBySafety` in the Firestore console.

## How To Test

- **Flutter:** `flutter test`. The 16 known failures are Call V2
  working-tree guards and two test-mode tests, caused by the local
  `ios/Podfile.lock` edit. Run them clean with
  `tool/run_clean_tree_guards.sh`. Any **other** failure is real.
- **Node:**
  `node --test connect_functions/test/{i18n,account,payments,notifications,call_invites,consultations,reviews,chat,safety}/*.test.js`
- **Rules** (run them serially):
  ```bash
  cd connect_functions && export JAVA_HOME=/opt/homebrew/opt/openjdk@17 PATH="/opt/homebrew/opt/openjdk@17/bin:$PATH"
  firebase --project demo-helperly-call-v2-rules --config ../firebase.json emulators:exec --only firestore \
    "node --test --test-concurrency=1 test/call_v2/firestore_rules_v2.test.js test/mvp/firestore_rules_age.test.js test/mvp/firestore_rules_mvp.test.js test/mvp/firestore_rules_reviews.test.js"
  ```
  Storage rules run separately with `--only firestore,storage` and
  project `demo-helperly-mvp-storage`.
- **Staging end to end:** `node tool/staging_smoke.mjs`. It has 24
  checks, refuses any project but staging, and deletes its accounts.
- **Staging app builds:** `tool/build_staging.sh android|ios`. It swaps in
  the configs from `config/staging/` and restores production's on exit.
  Extra flutter arguments pass through, for example
  `--dart-define=ENABLE_RUNTIME_DIAG=true`. Use that one briefly only: on
  iOS it causes a write loop.
- **Staging deploys:**
  - everything: `tool/deploy_staging.sh check|deploy`;
  - single pieces:
    `firebase deploy --only firestore:rules,functions:X --project helperly-call-v2-dev --force`.
- **Devices:**
  - **Android emulators** `helperly_a` (emulator-5554, staging account
    "Amira") and `helperly_b` (emulator-5556). The founder has no Android
    phone. Drive them with `~/Library/Android/sdk/platform-tools/adb`.
    Long-running emulators can lose system services; restart them with
    `~/Library/Android/sdk/emulator/emulator -avd helperly_a -port 5554 -no-snapshot-save -no-audio &`.
  - **iPhone:** the founder's iPhone 16 Pro Max (CoreDevice id
    `B38F87B5-FDBD-5CE8-8049-41DEE4134687`; Flutter UDID
    `00008140-001C641E1AE1801C`), connected by cable.
    - Install: `xcrun devicectl device install app`.
    - Live Flutter logs over USB do not work (Flutter 3.32 with iOS 26).
    - It normally runs the TestFlight (production) build. Reinstall it
      after any staging test.
  - **Test accounts:** staging only, created by scripts. Never use
    `test_artifacts/secrets/test_logins.txt` without the founder's
    approval.

## Next Steps (Priority Order)

1. **Founder-only blockers before inviting testers:**
   - a monitored `support@` and `privacy@` address;
   - a lawyer review of the drafts in `docs/legal-drafts/`;
   - signing the privacy impact assessment
     (`docs/legal-drafts/EFVP_PIA_DRAFT.md`);
   - business registration if needed.

   Then replace the placeholders, ask him, and deploy production hosting.
   Google Play requires the delete-account page.
2. **With browser access:**
   - App Store Connect: checked 2026-11-05. One internal group (2 team
     members, both on `202611040659`), no external group or public link,
     Test Information empty. Draft fields and the order of steps:
     `docs/TESTFLIGHT_TEST_INFO.md` (blocked on support address, privacy
     URL and demo accounts);
   - Firebase and Google Cloud consoles: verification; optionally a
     Vision quota and a $10 budget alert (the founder deferred this);
   - Google Play Console: only if Android testers appear.
3. **Beta invitation:** `docs/BETA_INVITATION.md` (FR first). Fill in the
   links and the support address.
4. **Small safety follow-ups:**
   - SafeSearch on post video thumbnails (`videoThumbUrl` in
     `postImageUrls`);
   - at scale, check only new accounts and reported posts, to save Vision
     cost.
5. **Later and needing approval:**
   - retention and TTL (`docs/RETENTION_POLICY_PROPOSAL.md`);
   - Call V2 rollout (off; not deployed);
   - paid sessions (off).
6. **Tech debt:**
   - upgrade `firebase-functions` (a deploy warning);
   - align local Flutter with CI 3.35.4;
   - the Podfile.lock noise in the guard tests.

## Working Style

- Make focused commits on `call-v2`, ending with the co-author line the
  harness gives. Push after each meaningful step.
- Verify before you claim:
  - after each deploy, check function state, rule identity and logs;
  - after UI changes, take an emulator screenshot, and on the iPhone
    when it is relevant.
- For staging, do it yourself. For production, prepare the exact command
  and the expected output, and let the founder run it. Then verify it
  read-only.
- Keep `docs/agent-loop/HANDOFF.md` and `docs/PRODUCTION_DEPLOY_PLAN.md`
  current when something ships.
- `AGENTS.md` describes an older review loop with ChatGPT (the `STATE.json`
  and `HANDOFF.md` steps). The founder no longer uses an outside reviewer.
  Keep the handoff files current anyway: they are the project's record.
