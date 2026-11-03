# Beta Operations Checklist (Smallest Practical)

**L** = legal requirement (Québec / Canada / stores);
**R** = recommendation. A private beta in Québec is **not** exempt from
the Charter of the French Language or Law 25.

## Identity And Contact

| # | Item | Type | Done |
|---|---|---|---|
| 1 | Business registration (Registraire des entreprises, about $40) if operating as "Helperly" | L | ☐ |
| 2 | Legal name of the operator, used in the Terms and the privacy policy | L | ☐ |
| 3 | Domain (for example `helperly.app`) and two addresses forwarded to a monitored inbox: `support@`, `privacy@` (Cloudflare Email Routing is free) | L (support contact: Apple, Google Play, Law 25) | ☐ |
| 4 | Person in charge of personal information = the founder; publish title and `privacy@` | L (Law 25) | ☐ |

## Legal Texts

| # | Item | Type | Done |
|---|---|---|---|
| 5 | A lawyer reviews the Terms and privacy policy, EN/FR drafts in `docs/legal-drafts/` | R (strongly) | ☐ |
| 6 | Publish Terms and privacy policy in **French and English**; French first for Québec users | L (Charter s.55 for the Terms; Law 25 transparency) | ☐ |
| 7 | Privacy impact assessment for transfers outside Québec (Firebase, Agora, Stripe): draft in `docs/legal-drafts/EFVP_PIA_DRAFT.md`; review and sign | L (Law 25) | ☐ |
| 8 | Confidentiality incident register: `docs/legal-drafts/INCIDENT_REGISTER.md` (first entry: the APNs key) | L (Law 25) | ☐ |

## Beta Communication (EN/FR)

| # | Item | Type | Done |
|---|---|---|---|
| 9 | Invitation message in French and English: free beta, 18+, peer experience and not professional advice, how to report, how to delete the account, support contact | L (French for Québec testers) and R | ☐ draft: `docs/BETA_INVITATION.md` |
| 10 | TestFlight and Play internal-testing descriptions in FR/EN | R | ☐ |

## Safety Operations

| # | Item | Type | Done |
|---|---|---|---|
| 11 | Who reviews reports: you, daily during the beta (Firestore `reports`, status `open`) | R | ☐ |
| 12 | Response targets: harassment or danger within 24 h; other reports within 72 h; block or suspend first, investigate after | R | ☐ |
| 13 | Restricted-minor accounts: review within 30 days (lift or delete) | R (data minimization) | ☐ |
| 14 | Deletion requests by email: confirm within 30 days | L (Play web deletion path, Law 25) | ☐ |

## People And Devices

| # | Item | Type | Done |
|---|---|---|---|
| 15 | First 5 helpers: people you know with relevant lived experience (housing, jobs, school, Québec procedures). A 15-minute call each to fill the profile, expertise and languages | R | ☐ |
| 16 | iPhone checks (`BETA_MANUAL_TESTS.md`), with the iPhone connected and you operating it | R (release gate) | ☐ |
| 17 | Android checks (emulators A/B and one real phone) | R (release gate) | ☐ |
| 18 | Password reset EN and FR with `+helperly-en` / `+helperly-fr` aliases of your Gmail | R | ☐ |
