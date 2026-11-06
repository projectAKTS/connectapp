# Privacy Impact Assessment (EFVP): Transfers Outside Québec (DRAFT)

Draft prepared 2026-11-02. It is **not legal advice**: a lawyer or privacy
professional must review it. Items marked [VERIFY] need confirmation.

**Legal basis:**
- Québec Private Sector Act (as amended by Law 25), s. 17: before
  communicating personal information outside Québec, assess the privacy
  impact. Communicate only if the information would receive adequate
  protection, and put the arrangements in a written agreement.
- s. 3.3: a privacy impact assessment for any project to acquire,
  develop or overhaul an information system that processes personal
  information.

## 1. Operator And Person In Charge

- **Operator:** [legal name, address, NEQ if registered].
- **Person in charge of the protection of personal information:**
  - the founder (by default, the person with the highest authority);
  - title and contact (`privacy@…`) published on the website [TODO].

## 2. Information Processed

| Category | Examples | Sensitivity |
|---|---|---|
| Account | email, display name, password (hashed by Firebase Auth) | Medium |
| Profile | photo, city, languages, expertise, bio, 18+ declaration | Medium |
| Communications | chat messages, chat images/videos | **High** (private content) |
| Calls | who called whom, when, how long. **No audio or video recording** | Medium |
| Safety | reports, blocks | High |
| Device | push tokens, app language, crash reports (opt-in only) | Low |
| Payments | none during the free beta. Later handled by Stripe, no card numbers stored by Helperly | — |

## 3. Where The Information Goes

| Provider | Purpose | Location | Safeguards |
|---|---|---|---|
| Google Firebase (Auth, Firestore, Storage, Functions, FCM) | Accounts, data, notifications | United States (`nam5`, `us-central1`) | Encryption in transit and at rest; Google Cloud data processing terms; access limited to the founder |
| Google Cloud Vision (SafeSearch) | Automatic check of **post** photos and post video thumbnails (one frame, not the video) for adult or violent content. Chat photos are not sent | Global endpoint `vision.googleapis.com`; the processing region is not pinned | Same Google Cloud terms; images are processed and not stored by Vision; only the verdict is kept on the post |
| Agora | Live audio/video transport | Global network; media is not stored | Encrypted transport; tokens per call; no recording enabled |
| Apple (APNs) / Google (FCM) | Push delivery | United States | Message previews only (sender name, text) |
| Stripe (later) | Payments | United States / Canada | PCI DSS; not active during the beta |
| Firebase Crashlytics / Analytics | Crash and usage statistics | United States | **Off by default**; opt-in in the app |

## 4. Assessment (s. 17 Factors)

- **Sensitivity:** private messages are the most sensitive data, followed
  by reports.
- **Purpose:** necessary to deliver the service (messaging, calls,
  notifications). No sale, no advertising, no profiling.
- **Protection measures:**
  - security rules: only participants read a chat; reports are private;
  - 18+ policy;
  - deletion on request: account deletion removes the profile, posts,
    files and Auth account;
  - minimal telemetry, opt-in only;
  - retention proposal in `docs/RETENTION_POLICY_PROPOSAL.md`.
- **Legal framework of the destination (United States):**
  - US authorities can compel access (for example under FISA 702 or the
    CLOUD Act).
  - Mitigation: the providers' contractual commitments; minimal data; no
    sensitive categories beyond private messages.
  - [VERIFY] whether this is judged "adequate" with these mitigations.
- **Conclusion (draft):** the transfer is acceptable for the free beta,
  provided that:
  - the privacy policy states it clearly;
  - the provider terms are accepted and kept on file;
  - the retention periods are applied.

## 5. Written Agreements To Keep On File

- [ ] Google Cloud / Firebase data processing terms (accepted in the console).
- [ ] Agora terms and data processing addendum.
- [ ] Apple Developer Program License Agreement (APNs).
- [ ] Stripe Services Agreement (before paid sessions).

## 6. Review

- Review again before:
  - paid sessions;
  - opening to minors;
  - adding analytics;
  - changing providers.
- Signature: ____________________ (person in charge), date ________.
