# KINDUPP MVP Release Checklist

Status as of Phase 3: **not ready for production release**. No production
website publish, DNS edit, Firebase deployment/configuration change, or mobile
store publication was performed.

## Code and build

- [ ] Review the Phase 3 diff and resolve all open code-review comments.
- [ ] Reconcile/restore dependency lockfiles only with the owner of the existing
      local edits; do not accidentally commit unrelated lockfile changes.
- [ ] Run full Flutter tests, scoped analyzer, Functions tests with local
      emulators, and Android/iOS no-publish builds; record actual results.
- [ ] Resolve Android release build failure: generated plugin registrant
      references dev-only `integration_test` absent from the release
      classpath. Confirm dependency metadata matches the Flutter SDK, then
      rebuild. Review API 35/API 36 plugin warnings and Kotlin 1.8.22 warning.
- [x] Build unsigned iOS Release app locally with `--no-codesign`; no store
      submission occurred.
- [ ] Test the exact signed candidate on physical Android and iOS staging
      devices, including auth, push, incoming calls, Agora calls, deletion,
      bilingual legal links and free consultation flow.
- [ ] Select and freeze the authoritative repository/commit and produce
      reproducible signed store binaries.

## Payments stay off for free MVP

- [ ] Verify production `MVP_PAYMENTS_ENABLED` and `PAID_SESSIONS_ENABLED` are
      false/unset and the deployed Functions include both fail-closed gates.
- [ ] Verify the release build uses production-default flags, no Stripe
      initialization/payment UI, no App Store subscriptions or boosts, and no
      payment/payout operations. Confirm signup does not create Stripe
      customers.
- [ ] Verify Stripe live mode has no active live payment or payout path. Source
      inspection is not proof of deployed behavior.

## Privacy, legal, operations

- [ ] Answer operator/contact, retention, processor/location, push-preview,
      analytics, underage response, moderation, deletion and product-claim
      questions in `KINDUPP-PRIVACY-INTEGRATION-REPORT.md`.
- [ ] Confirm production Firebase rules, regions, App Check, backups, Functions,
      Analytics/Crashlytics and deletion retry monitoring.
- [ ] Verify Agora settings and Vision, Netlify, Firebase and Apple/Google
      provider terms/data handling. Confirm no unreviewed AI vendor receives
      user data.
- [ ] Obtain qualified Québec/Canadian counsel review of Privacy, Terms,
      Community Guidelines, French-language versions and privacy impact
      assessment. Keep all documents marked as drafts until then.
- [ ] Test account deletion on a disposable production-like account after the
      reviewed functions are deployed; define retention periods and truthful
      completion support language.
- [ ] Confirm 18+ self-declaration and review the new underage-report category,
      staffing, urgent-response workflow and appeal/escalation path.

## Brand and web

- [ ] Verify text wordmark, favicon, social card, support email and draft legal
      page links in staging. Replace generic app icons only with approved art.
- [ ] Confirm Netlify recipient email and deliver a QA notification; handle the
      labeled QA row individually only after visual confirmation.
- [ ] Decide canonical domain and review current zone exports. Follow
      `KINDUPP-DOMAIN-CHECKLIST.md`; preserve all MX/forwarding/mail records.
- [ ] Separately approve and perform any website production publish, domain
      connection/DNS change, store metadata update, or Firebase deploy.

## External listings and launch operations

- [ ] Update Play/App Store metadata, privacy/support/deletion URLs and
      screenshots for the exact approved release.
- [ ] Confirm support mailbox ownership and monitoring, moderation owner,
      report response/escalation, incident register and operational coverage.
- [ ] Complete taxes/business-registration decisions with qualified local
      advice; no registration or tax action was performed here.
