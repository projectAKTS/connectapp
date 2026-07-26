# Call V2 Manual iPhone Smoke Checklist

This checklist is developer-only. Production rollout remains disabled.

## Prerequisites

- Use a development Firebase project with the gated `callV2RtcToken` callable intentionally enabled for the test environment only.
- Use an Agora App ID and server-issued token from the development callable.
- Install the app on two iPhones from a development build.
- Do not print or capture tokens, routing handles, numeric handles, user identifiers, call identifiers, device labels, or raw provider payloads in logs.

## Device A

1. Open the hidden developer-only Call V2 manual entry.
2. Select internal real-device mode.
3. Enter the shared call/session value selected for the smoke test.
4. Enter local participant A.
5. Enter remote participant B.
6. Enter the development Agora App ID.
7. Choose audio or video.
8. Tap Create Manual Runtime.
9. Tap Start Audio or Start Video.
10. Confirm the app reaches permission preflight.
11. Tap Request Permissions.
12. Grant microphone for audio; grant microphone and camera for video.
13. Tap Request Access.
14. Confirm the access step succeeds without unsafe logs.
15. Tap Initialize RTC.
16. Tap Join RTC.
17. Tap Activate.
18. Confirm the state shows active.

## Device B

1. Open the same hidden developer-only Call V2 manual entry.
2. Select internal real-device mode.
3. Enter the same shared call/session value used on Device A.
4. Enter local participant B.
5. Enter remote participant A.
6. Enter the same development Agora App ID.
7. Choose the same audio or video mode.
8. Tap Create Manual Runtime.
9. Repeat Start, Request Permissions, Request Access, Initialize RTC, Join RTC, and Activate.
10. Confirm audio/video media behavior manually.

## End And Recovery

1. Tap End on both devices.
2. Tap Dispose/Reset if needed.
3. Confirm repeated End and Dispose/Reset remain harmless.
4. Confirm permission denial, access failure, initialize failure, and join failure show controlled failure states.
5. Collect logs only after confirming they contain no unsafe identifier words or values.

## Troubleshooting

- Permission denied: confirm the explicit permission button was used, then reset iOS permission settings if the OS permanently denied access.
- Token disabled: confirm the Firebase project is a development/staging/demo target and the Call V2 RTC token gate is intentionally enabled for that target only.
- Invalid request: confirm the shared session and participant fields are non-empty, under 128 characters, and contain no slash or path characters.
- Agora rejected: confirm both devices use the same development Agora App ID and the callable is using matching development Agora credentials.
- Join timeout: confirm both devices used the same shared session value and reversed local/remote participant values.
- No audio/video: confirm microphone/camera permission was granted, both devices joined, and only safe state diagnostics are logged.
- Safe logs checklist: logs must not include access strings, routing handles, numeric handles, user identifiers, call identifiers, device labels, raw payloads, or stack traces.
