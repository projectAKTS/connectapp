# Kindupp Netlify Contact Form Report

The Phase 2 Netlify Forms review found one notification recipient configured:
`support@kindupp.ca`, with Netlify showing the recipient as awaiting email
confirmation. This Phase 3 code work did not change the Netlify site or form.

## Confirming notifications

1. Open the confirmation message sent by Netlify to `support@kindupp.ca` and
   follow its recipient-confirmation link.
2. In Netlify, open the Kindupp site and its Forms/Notifications settings;
   verify that `support@kindupp.ca` shows confirmed for the `kindupp-contact`
   form.
3. Submit a new clearly labeled test (for example, subject `Kindupp QA
   notification test`) through the private preview; confirm the message arrives
   at the inbox and check spam/quarantine.
4. Remove the test entry only after identifying that exact test row.

No mailbox credential is needed by engineering; do not share mailbox access.

## QA submission deletion

Phase 2 found a single submission labeled **Kindupp QA preview**. Deleting that
individual row is safe only after visually confirming the exact form, label,
timestamp and test message in Netlify. Do not use bulk deletion and do not
delete any ambiguous or customer-looking submission. It was not deleted in
this work. Confirm current row state before acting because the earlier snapshot
may have changed.

Netlify location, access control, spam handling and retention/deletion policy
remain owner/provider verification items for the Privacy draft.
