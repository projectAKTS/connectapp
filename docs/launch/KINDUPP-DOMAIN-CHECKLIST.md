# Kindupp Domain Checklist

**No DNS was changed; no production domain was connected.** The actual current
registrar-zone records were not exported in this phase. Preserve all existing
MX, forwarding, SPF, DKIM, DMARC, verification and service records. Use the
site-specific values shown by Netlify when a separate domain-connection step is
approved; do not copy generic IP/CNAME values from old notes.

## `kindupp.com`

- [ ] Decide whether this is canonical (planned: `https://kindupp.com`).
- [ ] Export and review current zone, TTLs and existing mail/service records.
- [ ] Confirm correct Netlify site and obtain current apex plus `www` values.
- [ ] Add only approved web records; use supported ALIAS/ANAME/flattening or
      Netlify's shown fallback for apex and the shown target for `www`.
- [ ] Wait for HTTPS; verify apex, `www`, canonical URLs, favicon and social card.
- [ ] Decide/verify redirect behavior for `www`.

## `kindupp.ca`

- [ ] Export and preserve all mail forwarding, MX, SPF/DKIM/DMARC and other TXT
      records; verify `support@kindupp.ca` mail delivery independently.
- [ ] Confirm Netlify recipient email confirmation and test notification.
- [ ] Review existing web/service records and conflicts before adding anything.
- [ ] If approved as an alias, use the site's current apex/`www` values and wait
      for HTTPS before redirecting to the canonical host.

## `kindupp.app`

- [ ] Export and review the zone, including any mail/service records.
- [ ] Decide whether it should resolve, redirect, or remain unused.
- [ ] If approved, use only current Netlify site-specific values, preserve mail
      records, wait for HTTPS, then verify the chosen redirect.

Do not connect domains or edit DNS until the owner approves the canonical-host
decision and exact exported records have been reviewed.
