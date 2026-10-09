# Active Task - Call Route Ownership And Authoritative Terminal Transition

Branch: `call-v2`

Starting SHA: `f6dedab4a0b60c60d6c1d0f9aac970fe6cb8d607`

## Goal

Make every legitimate call-route exit lifecycle-managed, classify route-exit
terminal transitions from authoritative Firestore state, preserve exact
route/session ownership across sequential calls, and defer destructive chat
navigation until the call lifecycle is safe.

This task must preserve the already validated exact CallKit ownership,
repeated-call behavior, accepted recovery design, and redial-gate ordering.

## Authorized Scope

### 1. Managed Call-Route Exits

- Intercept Audio implicit AppBar Close, loading/error/ended call UI exits,
  system back, Android back, and normal user-initiated route pops.
- Route every active nonterminal user exit through one managed termination
  coordinator.
- Do not permit direct `Navigator.pop()` or `Navigator.maybePop()` to bypass
  call lifecycle termination.
- Keep an already-terminal auto-close as a UI-only close without a second
  terminal write.
- Preserve automatic failure reasons already established by Agora failure,
  join timeout, or remote failure.
- Enforce equivalent exit ownership for Audio and Video modes even where their
  UI chrome differs.

### 2. Authoritative Terminal Transition

- Replace stale-local-status terminal classification on route close with a
  guarded authoritative Firestore transaction or equivalent existing
  authoritative mechanism.
- Authoritative `ringing` plus caller exit may transition to `cancelled`.
- Authoritative `accepted`, `joining`, or `connected` plus participant exit
  must transition to `ended`.
- An already-terminal authoritative status must be preserved without a second
  terminal overwrite.
- A stale local `ringing` state must never regress authoritative `accepted`,
  `joining`, or `connected` to `screen_closed_before_accept` / `cancelled`.
- Preserve recipient/session validation and existing terminal ownership rules.

### 3. Exact Route And Session Ownership

- Give each pushed call route immutable ownership sufficient to identify its
  invite, exact CallKit ID when available, lifecycle generation, and session.
- Check exact ownership before clearing global route-active state.
- A delayed Call A route completion must not clear Call B route ownership,
  terminate B, mutate B's lifecycle generation, classify B's terminal state,
  or pop B's route.
- Duplicate route-completion callbacks for one call must remain idempotent.

### 4. Deferred Chat Navigation

- Prevent `NotificationService._flushPendingChatOpen()` from performing
  destructive root navigation while the call lifecycle owns an active route.
- Retain the pending chat-open request while blocked.
- Resume it only after the call lifecycle reaches a safe idle state.
- Do not weaken call ownership to accommodate chat navigation.

## Authorized Files

Modify only files strictly required from:

- `lib/screens/call/agora_call_screen.dart`
- `lib/services/call_session_manager.dart`
- `lib/services/notification_service.dart`
- focused regression files under `test/call_v2/**`
- `test/notification_foreground_recovery_test.dart` only if required for the
  deferred chat-navigation regression

Do not modify native code, backend code, dependency metadata, or platform
configuration.

## Strict Non-Goals

Do not change:

- PushKit or APNs delivery/presentation
- exact CallKit UUID propagation or exact-end ownership
- accepted recovery transaction architecture
- Firestore accept transaction retry architecture
- Agora media, token, channel, or engine-gate behavior
- post-call redial-gate ordering
- native watchdog timing or semantics
- backend functions, Firestore rules, or schemas
- dependency, Flutter, Agora, or `flutter_callkit_incoming` versions
- Audio B APNs delivery behavior
- isolated Video `userOfflineQuit` behavior

Do not increase timeouts, build TestFlight, deploy, or claim physical success.

## Required Regression Tests

1. Stale local `ringing`, authoritative `accepted`, then route close results in
   `ended`, never `cancelled` or `screen_closed_before_accept`.
2. Stale local `ringing`, authoritative `joining`, then route close results in
   `ended`.
3. Stale local `ringing`, authoritative `connected`, then route close results
   in `ended`.
4. Authoritative `ringing` plus caller exit still results in `cancelled`.
5. Existing terminal states (`declined`, `missed`, `cancelled`, `ended`, and
   `failed`) are preserved on route close.
6. Active Audio AppBar Close uses the managed termination path.
7. Loading Close uses the managed path for applicable Audio and Video states.
8. System/back exit executes one managed termination path and one terminal
   write.
9. Terminal auto-close performs no new terminal write.
10. Existing Agora failure, join-timeout, and remote-failure reasons survive
    route closure.
11. Chat open during an active call is deferred without removing the call
    route, then executes after safe idle.
12. A delayed Call A route callback cannot clear, terminate, mutate, or pop
    current Call B.
13. Duplicate route completion is idempotent and preserves native ownership.
14. Audio and Video satisfy the same route-exit ownership invariant.

## Required Adversarial Review

- Race A: local `ringing` -> remote `accepted` -> route close -> authoritative
  terminal transaction must produce `ended`.
- Race B: delayed old A route callback while B owns the route must leave B
  untouched.
- Race C: chat-open request during an active call must preserve the call route
  and defer navigation.
- Race D: terminal call auto-close and route completion must not perform a
  second terminal mutation.

## Validation

Run and pass:

```bash
flutter analyze
flutter test test/call_v2 --no-pub
flutter test test/notification_foreground_recovery_test.dart --no-pub
git diff --check
```

Also run the focused new route/terminal tests, exact CallKit ownership tests,
NotificationService ownership tests, rapid lifecycle tests, repeated lifecycle
tests, foreground recovery tests, and iOS RunnerTests. Inspect dependency and
lockfile diffs and confirm they are unchanged.

## Commit And Handoff

After validation, create one focused implementation commit, update the
agent-loop handoff and state to `ready_for_review` in a separate metadata
commit, push `origin/call-v2`, and stop. Do not build TestFlight, deploy, request
physical testing, or claim the physical issue fixed.
