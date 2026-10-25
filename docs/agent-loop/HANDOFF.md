# Stale CallKit Plugin Identity Isolation Handoff

STATUS: `ready_for_review`

STARTING_SHA: `3500609828afa6e28eae5896a08b0e8c0ec5c272`
AUTHORIZATION_SHA: `29adef1dc964e39b9c879304b7d4e5dc74d874b8`
IMPLEMENTATION_SHA: `624bca530e370dd345e6a13531aab5075b7a66ad`
ENDING_SHA: `SELF`

## Physical Evidence (2026-10-22, receiving device, build 202610211427)

Native durable events: Call A presented 23:49:02.113 and declined 23:49:06.124;
Call B presented 23:49:09.421 and natively accepted 23:49:11.288. Flutter durable
events: an accepted-recovery classification for **A's** call and exact CallKit
fingerprints at 23:49:11.290 (`ownerMissing`), then the exact native bridge for
**B** at 23:49:11.291. B connected; the call ended at 23:49:15.330.

## Code-Level Causal Sequence (proven on the unchanged baseline)

1. `flutter_callkit_incoming` 3.0.0 sends `ACTION_CALL_ACCEPT` with its global
   `self.data`, replaced only by `fromPushKit: true` presentations. AppDelegate's
   Flutter-driven `ensureIncomingCallkit` presents with `fromPushKit: false`, so
   the accept event for B carried A. Decline, provider timeout, and unknown-UUID
   end events use the same `self.data`.
2. Flutter treated the plugin identity as accepted: it remembered A as recently
   accepted and started accepted recovery for A.
3. A's accepted-native watch observed Firestore `declined` and set the
   manager-wide, identity-free `_acceptedRouteTerminalObserved = true` (only
   `forceIdleForTest` ever reset it).
4. `handleRecoveredAcceptedInvite(B)` found no matching continuation, saw the
   flag, and returned `terminal` for B; NotificationService stopped retrying.
5. Independently, A's superseded continuation awaited A's watch cleanup, which
   resumes the pending B; `resumePendingAcceptedRouteIfReady` returned the
   in-flight future of any continuation, so B joined A's future: an async cycle.
6. B never opened. At the 20 s native-watch deadline B was marked `failed` and
   its exact CallKit call was ended.

## Correction

- `AppDelegate.getCallkitPresentationState` (read-only): exact presentation
  ledger state plus whether `CXCallObserver` still lists the exact UUID as not
  ended (covers ledger expiry during calls longer than 120 s). No presentation,
  PushKit, audio-session, CallKit action, or watchdog change.
- `NotificationService._handleCallkitPluginEvent`: plugin accept is acted on
  only when native reports the exact call accepted/active; otherwise it is
  rejected and re-attributed to the exact native stored accepted identity.
  Decline/timeout use the exact native last event for the same action, or are
  rejected when native shows the plugin's call still live. Ended is rejected
  when native shows the call live; a ledger-verified exact end bypasses the
  legacy synthetic post-accept filter. Unavailable native state keeps the
  previous behavior. Durable stages `pluginEventIdentityRejected` and
  `pluginEventIdentityReattributed` record only hashed fingerprints.
- `CallSessionManager`: accepted-route terminal observation and native cleanup
  waits are scoped to exact invite/CallKit identity and lifecycle generation;
  accepted-route single-flight is per exact continuation.

## RED / GREEN

The identical file `test/call_v2/real_flow/call_v2_stale_callkit_plugin_identity_test.dart`
(SHA-256 `39060053fa8c0c0d0cb96d5b61b1b5006b3b85d03e8c0c65aae695253159fb66`) was run
against the authorization baseline plus test-only seams (plugin-event hook and
injectable native state, no behavior change): 4 passed, 12 failed. After the
correction: 16 passed. The manager-isolation regression uses only hooks that
exist on the unchanged baseline and fails there with `Expected: ['invite_b']
Actual: []`.

The 4 baseline-passing tests are legitimate-behavior guards (same-call
plugin/native duplicates in both orders, plugin-only legitimate accept, stale end
for live B masked by the recent-accept window) and stay green.

## Validation

- New regression file: 16 passed.
- Focused real-flow and diagnostics suites: 273 passed.
- Complete Call V2 suite (clean worktree at the implementation SHA): 2,405 passed.
- iOS RunnerTests (iOS 26.0 simulator, iPhone 17 Pro): 31 passed, 0 failed, 0 skipped.
- `flutter analyze`: no issues. Format check: 4 Dart files unchanged.
- `git diff --check`: passed. Dependency and lockfile diff: none.

Untracked Aider/architecture artifacts were not moved, modified, or committed.

## Venus Stuck "Call ended" Screen (separate)

Not attributed to this defect. Build 202610211427 (`b8f29c2`) predates the
`clearStaleUiFlags` ownership correction and the covered/detached/one-shot
terminal-route corrections, all proven source defects, but that build persisted
no route-exit decision, so which path stranded Venus is not established. The B
end at 23:49:15.330 reached native `onEnd` with B's exact call object,
consistent with a normal hangup. The current branch persists terminal route
outcomes for the next controlled physical test.

## Remaining Risks

- Native ordering relies on the plugin provider delegate running on the main
  queue (`setDelegate(self, queue: nil)` in 3.0.0); a plugin upgrade must be
  re-verified.
- The native single last-event slot can be overwritten by audio-session events;
  decline/timeout re-attribution then falls back to ledger contradiction checks.
- A ledger-verified CallKit end within 20 s of acceptance now ends the Flutter
  session instead of being ignored as synthetic.
- Video C's historical failure is plausibly explained by the same defect but
  no Video C evidence exists.

## Scope And Limitations

No TestFlight build, deployment, backend/Firebase change, physical call,
dependency change, RTC/Agora change, PushKit/APNs change, CallKit presentation or
action change, cleanup-gate change, or terminal-route semantic change occurred.

PHYSICAL_FIX_CLAIM: `NONE`

## Next

Review the plugin identity validation and identity-scoped accepted-route state
before authorizing a controlled TestFlight build.
