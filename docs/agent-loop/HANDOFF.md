# External Review Handoff

Phase: 3A
Status: revision_required
Rejected implementation: `ca57d4ad6c6878f0424783f8d94b8493390a1146`
Workflow: `28348917545`

The workflow passed, but exact code review found behavioral contract defects:

- `CallV2RequestContext` and request payloads include `actorUid`, violating the no client-supplied authenticated UID rule.
- A parallel `call_v2_models.dart` duplicates accepted domain models and changes required local-phase names from `presentingIncoming` / `openingCallRoute` to incompatible alternatives.
- The manager's queued-command key is unused, so duplicate taps generate two requests instead of one.
- The manager does not derive ringing phase from current participant role.
- Equal-version snapshots are not deduped; a terminal snapshot may be replaced by lower/equal data.
- Terminal cleanup does not clear ownership or return to idle.
- The navigation coordinator has no dedupe state and emits repeated open/close intents.
- The tests explicitly expect two duplicate accept requests and do not actually test navigation dedupe.
- Error normalization is a generic message rather than a controlled client error-code contract.

`NEXT_TASK.md` now contains bounded corrections and required behavioral tests. V1 was untouched, the feature gate remains disabled by default, no production service was contacted, no live configuration changed, and nothing was deployed.
