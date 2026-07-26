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
3. Tap Start Audio or Start Video.
4. Confirm the app reaches permission preflight.
5. Tap Request Permissions.
6. Grant microphone for audio; grant microphone and camera for video.
7. Tap Request Access.
8. Confirm the access step succeeds without unsafe logs.
9. Tap Initialize RTC.
10. Tap Join RTC.
11. Tap Activate.
12. Confirm the state shows active.

## Device B

1. Open the same hidden developer-only Call V2 manual entry.
2. Use the same development call setup supported by the test callable.
3. Repeat Request Permissions, Request Access, Initialize RTC, Join RTC, and Activate.
4. Confirm audio/video media behavior manually.

## End And Recovery

1. Tap End on both devices.
2. Tap Dispose/Reset if needed.
3. Confirm repeated End and Dispose/Reset remain harmless.
4. Confirm permission denial, access failure, initialize failure, and join failure show controlled failure states.
5. Collect logs only after confirming they contain no unsafe identifier words or values.
