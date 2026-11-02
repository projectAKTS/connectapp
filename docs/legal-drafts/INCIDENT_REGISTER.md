# Confidentiality Incident Register (template)

**Required by:**
- Québec Private Sector Act, s. 3.8: every confidentiality incident is
  recorded, even a minor one;
- the Regulation respecting confidentiality incidents;
- PIPEDA, s. 10.3 (breach records) for Canada-wide activities.

**Keep each entry** at least **5 years** after the date the organization
became aware of the incident [VERIFY: Law 25 regulation; PIPEDA requires
24 months].

**What counts as an incident:**
- unauthorized access to, use of, or communication of personal
  information;
- loss of personal information;
- any other breach of its protection.

Examples: a leaked key, a misconfigured rule, a lost phone with an admin
session.

**If there is a risk of serious injury:**
- notify the Commission d'accès à l'information (CAI) and the people
  affected **promptly**;
- notify the Office of the Privacy Commissioner (OPC) when PIPEDA
  applies.

**Factors for the risk:** the sensitivity of the information, the
consequences of its use, and the likelihood of misuse.

## Entry Template

| Field | Value |
|---|---|
| No. / date recorded | |
| Description of the personal information involved | |
| Circumstances (what happened, cause) | |
| Date or period of the incident | |
| Date the organization became aware | |
| Number of people affected (or estimate) | |
| Risk of serious injury: assessment and reasons | |
| Notified CAI / OPC? Date | |
| Notified the people affected? Date and how | |
| Measures taken to reduce the risk and prevent recurrence | |
| Closed on | |

## Entries

### 2026-11-02: APNs Private Key Shown In An AI Coding Session

| Field | Value |
|---|---|
| Information involved | Apple push key (`.p8`, key `AJDC73P524`). This is a **credential, not personal information**: it allows sending pushes to app users, not reading their data |
| Circumstances | The key file was open in an editor and selected. The selection was sent to the AI coding assistant during development |
| Date / awareness | 2026-11-02 / 2026-11-02 |
| People affected | 0 known. No user data was exposed |
| Risk of serious injury | Low. Misuse would allow unwanted pushes to users; it gives no access to data |
| Notifications | Not required (no personal information; no risk of serious injury) [VERIFY] |
| Measures | New key `A55R9GWWX2` created and deployed (staging and production). The old key is revoked after 24 hours of verified operation. Do not open key files in editors |
| Closed on | (after the old key is revoked) |
