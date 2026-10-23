# Active Revision - Complete Terminal Route Reliability Investigation

Branch: `call-v2`

Starting SHA: `dd0a6db86b94ec8ce210d588bb6679aa33f22793`

## Goal

Complete a source- and evidence-driven audit of every iOS Call V2 terminal
route exit, reproduce every discovered permanent `Call ended` route failure on
the unchanged checkpoint, and implement only the smallest cohesive corrections
proven by identical red-to-green regressions.

## Allowed Files

- `lib/screens/call/agora_call_screen.dart`
- `lib/services/call_session_manager.dart`
- `lib/services/notification_service.dart`
- directly relevant Call V2 tests under `test/call_v2/**`
- `test/notification_foreground_recovery_test.dart`
- directly relevant existing iOS test harness files under `ios/RunnerTests/**`
- `ios/Runner/AppDelegate.swift` only if a native test proves a production
  bridge defect that cannot be covered through the existing bridge
- directly relevant existing Flutter integration-test files, if required
- `docs/agent-loop/NEXT_TASK.md`
- `docs/agent-loop/STATE.json`
- `docs/agent-loop/HANDOFF.md`

## Required Investigation And Proof

- Preserve and inspect retained physical/native/Flutter/Agora/Firestore
  evidence without placing new calls or altering evidence.
- Audit every production path that can display `Call ended`, every route-owner
  mutation while a route is mounted, and every eventual route-removal path.
- Exercise the actual NotificationService stale-native reconciliation logic
  through the closest technically supported iOS/native integration boundary;
  document simulator or PushKit limitations precisely.
- Deterministically cover the twenty terminal interleavings in the user
  directive with controlled barriers and real manager-owned Navigator routes.
- For each newly discovered production defect, capture baseline-red output
  before changing production code, then run the identical regression green.
- Every legitimate terminal route must either dispose safely and reveal Home,
  or yield to a newer exact route without mutating or dismissing it.
- Normal terminal-to-Home behavior must complete within 2,000 ms of simulated
  time and must not await slow Firestore, Agora, or CallKit cleanup.

## Strict Non-Goals

Do not alter tokens, Agora join/media configuration, PushKit/APNs delivery,
Firestore schema/rules or accepted-authority protocol, Firebase/backend,
dependencies, release configuration, or watchdog timing without a separately
reproduced and source-proven necessity. Do not build/upload TestFlight, deploy,
place physical calls, or request another physical test.

## Validation

Run all new baseline and corrected regressions, route ownership and terminal
transition tests, background accepted audio, exact CallKit ownership,
physical-media and cleanup-gate tests, accepted recovery, repeated/sequential
call tests, foreground recovery, supported iOS RunnerTests/integration tests,
the complete Call V2 suite, `flutter analyze`, formatting checks, dependency
diff inspection, and `git diff --check`.

## Commit And Handoff

Commit production/test implementation separately from the final agent-loop
handoff. Replace `HANDOFF.md`, set `STATE.json` to `ready_for_review`, commit
metadata, push `origin/call-v2`, and stop. Do not claim physical correctness.
