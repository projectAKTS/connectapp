# Call V2 Dev Firebase Project Setup

This guide is developer-only. Do not use the production Firebase project for the Call V2 RTC token smoke path.

## Project Selection

Use a Firebase project whose project ID or explicitly approved alias clearly indicates one of:

- `dev`
- `demo`
- `staging`
- `test`
- `emulator`
- `local`

If the only available project is `connectapp-278b4`, treat deployment as blocked until a human confirms a separate non-production Firebase target.

Safe inspection commands:

```bash
firebase projects:list
firebase use
firebase target
firebase functions:config:get
```

Do not paste secrets from command output into tickets, logs, screenshots, or chat.

## Required Parameters And Secrets

Configure only the dev Firebase project:

```bash
firebase use <dev-project-alias-or-id>
firebase functions:secrets:set AGORA_APP_ID --project <dev-project-id>
firebase functions:secrets:set AGORA_APP_CERTIFICATE --project <dev-project-id>
firebase functions:params:set CALL_V2_RTC_TOKEN_ENABLED=true --project <dev-project-id>
firebase functions:params:set CALL_V2_ENV=dev --project <dev-project-id>
firebase functions:params:set CALL_V2_REGION=us-central1 --project <dev-project-id>
```

The callable remains disabled unless `CALL_V2_RTC_TOKEN_ENABLED` is true and `CALL_V2_ENV` is one of the allowed non-production values.

## Dev-Only Deploy Command

Deploy exactly one function, and only to the confirmed non-production project:

```bash
firebase deploy --only functions:callV2RtcToken --project <dev-project-id>
```

Do not deploy hosting, Firestore rules, storage rules, scheduled functions, triggers, or any other callable.

## Smoke Verification

Use the app's manual developer screen. Do not print token values, routing handles, numeric handles, participant identifiers, session identifiers, device labels, raw payloads, or stack traces.

Safe verification output may include only:

- access ready
- routing ready
- numeric handle ready
- expiry present
- selected media mode

If the callable returns disabled, confirm the selected Firebase project is non-production and that the dev-only parameters were set on that same project.
