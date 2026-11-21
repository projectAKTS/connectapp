# KINDUPP Account Deletion Review

## What the reviewed callable does

The user-initiated server flow records an in-progress deletion and then removes
the Firebase Auth user, the user's Firestore document/subcollections, authored
posts and their subcollections, follower records, selected cross-user
references, and Storage objects under `users/{uid}/`, `post_images/{uid}/`,
`post_videos/{uid}/`, and `post_video_thumbs/{uid}/`. It scrubs/deletes authored
comments/replies and review text; some review stars are retained anonymously.
The scheduled retry handles unfinished deletion records and operations are
designed to be idempotent.

## Data that remains or may remain

- Messages and chat media already in another participant's conversation.
- Reports, call invites (including records with the deleted user's name
  scrubbed), and consultations.
- Stripe customer/connected-account/payment-provider records.
- Backups, provider logs, and any items missed by failed cleanup. No overall
  retry-age cutoff or guaranteed completion deadline was found.

The policy draft no longer promises immediate or 30-day completion. The public
deletion page says the app removes most profile data and lists possible retained
records. Production callable/scheduler deployment and actual successful deletion
must still be verified.

## Questions for the operator

- What retention period and purpose apply to reports, call invites, chat/media
  retained for recipients, consultations/payment records, backups, and deletion
  retry records?
- Should deletion workflow fail visibly or alert an operator after a chosen
  retry threshold? What completion time can support honestly promise?
- Which Stripe customer/connected-account data can be deleted versus retained,
  and who is responsible for those requests?
- Who handles identity verification, status updates and privacy-rights requests
  sent to `support@kindupp.ca`?

No account data was deleted during this review.
