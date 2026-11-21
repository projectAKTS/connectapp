# Kindupp Brand Asset Status

No separate approved Kindupp logo or brand-kit file was found in the app/web
assets reviewed. The approved existing website wordmark is the text treatment
`kindupp.` with an orange dot. Existing launcher/web app icons are generic
Flutter icons, not an approved brand mark; they remain unchanged.

The current text wordmark is used as requested. Prepared assets:

- `public/favicon.svg`: existing `kindupp.` text wordmark and colors.
- `public/og-kindupp.png`: 1200×630 social card with that wordmark and the
  existing “Real experience. Human connection.” site tagline. It contains no
  new symbol or illustration.
- `tool/build_legal_site.py` adds favicon, Open Graph and Twitter large-card
  metadata to generated pages.
- The same assets and metadata are prepared in the Netlify preview source at
  `outputs/kindupp-site/public/`; no redeploy was performed.

These are prepared source assets only; they have not been deployed or tested
against a connected production domain. Replace the generic app icons only after
the owner supplies/approves a final app icon asset. Verify the text treatment
and tagline before production sharing.
