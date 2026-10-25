# Active Revision - Stale CallKit Plugin Identity Isolation

Branch: `call-v2`

Starting SHA: `3500609828afa6e28eae5896a08b0e8c0ec5c272`

Authorized by the user on 2026-10-24 after the independent takeover audit.

## Proven Defect

`flutter_callkit_incoming` 3.0.0 emits iOS accept, decline, provider-timeout,
and unknown-call end events with its process-wide `self.data`, which is only
replaced by `fromPushKit: true` presentations. Flutter-foreground presentation
uses `fromPushKit: false`, so a plugin event can carry a previous call's
identity. Recovered physical evidence from 2026-10-22 shows the plugin accept
event for declined Call A arriving 1 ms before the exact native bridge for
accepted Call B.

`CallSessionManager._acceptedRouteTerminalObserved` is not identity-scoped.
A's accepted-native watch observes A's authoritative decline, then
`handleRecoveredAcceptedInvite(B)` returns `terminal` for B. B is never opened,
reaches the 20 second native watch deadline, is marked `failed`, and its exact
CallKit call is ended. A deterministic production-path reproduction fails on
the unchanged baseline.

## Goal

Treat exact native CallKit identity as authoritative, reject or re-attribute
plugin events whose identity native state contradicts, and scope accepted-route
terminal observation and cleanup waits to the exact call identity and lifecycle
generation so a terminal observation for A can never terminate or suppress B.

## Allowed Files

- `lib/services/notification_service.dart`
- `lib/services/call_session_manager.dart`
- `lib/call_v2/diagnostics/call_v2_durable_boundary_diagnostics.dart`
- `ios/Runner/AppDelegate.swift` (read-only exact presentation-state query only)
- `ios/RunnerTests/RunnerTests.swift`
- directly relevant tests under `test/call_v2/**`
- `docs/agent-loop/NEXT_TASK.md`
- `docs/agent-loop/STATE.json`
- `docs/agent-loop/HANDOFF.md`

## Required Implementation

- Add a read-only native query for the exact per-CallKit presentation ledger
  state. No presentation, PushKit, audio-session, or CallKit action changes.
- Validate iOS plugin accept, decline, ended, and timeout identities against
  exact native state before acting. Contradicted identities are rejected with
  privacy-safe diagnostics; accept/decline/timeout are re-attributed to the
  exact native identity when native records one. Unavailable native state keeps
  the existing behavior. Legitimate foreground and background acceptance,
  same-call plugin/native duplicates, and stored accepted recovery keep working.
- Scope accepted-route terminal observation and accepted-native cleanup waits
  to exact invite/CallKit identity and lifecycle generation.
- Persist the permanent RED regression for A declined then B accepted with
  mismatched plugin and native identity, plus adversarial coverage for: plugin
  first, native first, valid same-call duplicates, delayed A terminal after B
  connects, B declined in foreground, B ended with stale plugin state, repeated
  calls without leaked recovery retry timers, B staying connected without
  premature CallKit cleanup, and Audio A -> Audio B -> Video C isolation.

## Strict Non-Goals

Do not change RTC/media setup, Agora, token flow, Firestore authoritative
transitions, PushKit/APNs delivery, CallKit presentation or actions, audio
session handling, native safety watchdog behavior, cleanup gates, terminal-route
navigation semantics, retry limits, dependencies, lockfiles, backend/Firebase, or
release configuration. Do not build/upload TestFlight, deploy, or place
physical calls. Do not claim this defect caused the historical Venus stuck
"Call ended" screen without evidence.

## Validation

Run the new regression file against the unchanged baseline (RED) and after the
fix (GREEN), affected notification/recovery/lifecycle/route regressions, the
complete Call V2 suite, iOS RunnerTests, `flutter analyze`, formatting checks,
dependency/lockfile diff inspection, and `git diff --check`.

## Commit And Handoff

Commit implementation/tests separately from the final agent-loop handoff. Replace
`HANDOFF.md`, set `STATE.json` to `ready_for_review`, commit metadata, push
`origin/call-v2`, and stop. Do not claim physical verification or 100% reliability.
