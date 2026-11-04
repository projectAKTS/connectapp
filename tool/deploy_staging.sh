#!/bin/bash
# STAGING deploy for helperly-call-v2-dev. Never targets production.
#   tool/deploy_staging.sh check    -> isolation checks only (no changes)
#   tool/deploy_staging.sh deploy   -> checks, then deploys (founder-approved runs only)
set -euo pipefail
ROOT=$(git rev-parse --show-toplevel); cd "$ROOT"
P=helperly-call-v2-dev
PROD=connectapp-278b4
PROD_AGORA_APP_ID=dac900a04a87460c87c3d18b63cac65d   # public, in app source
MODE=${1:-check}

# The 18 functions live in production plus the 3 new ones. Call V2
# functions (startCallV2 ... recoverCallV2TaskOutbox) are never deployed by
# this script; the existing callV2RtcToken in staging is left as is.
FUNCS=(callInviteTransition getAgoraRtcToken onCallInviteCreated onCallInviteUpdated
  onChatMessageCreated onAuthUserCreated healthCheck scheduledConsultationReminder
  createStripeCustomer createSetupIntent listPaymentMethods setDefaultPaymentMethod
  removePaymentMethod cancelConsultation chargeStoredPaymentMethod
  createExpressAccountLink createStripeCheckoutSession handleStripeWebhook
  deleteAccount processAccountDeletionRequests onReviewCreated onReportCreated onPostImagesChanged)

fail() { echo "STOP: $*" >&2; exit 1; }
[ "$P" != "$PROD" ] || fail "target is production"
for f in "${FUNCS[@]}"; do
  case "$f" in *V2*) fail "Call V2 function in list: $f";; esac
done
ENV=connect_functions/.env.$P
[ -f "$ENV" ] || fail "missing $ENV"
grep -q '^PAID_SESSIONS_ENABLED=false$' "$ENV" || fail "PAID_SESSIONS_ENABLED=false missing in $ENV"
grep -qi '^CALL_V2_ENABLED=false$' "$ENV" || fail "CALL_V2_ENABLED must be false in $ENV"
grep -q "$PROD" "$ENV" && fail "$ENV mentions the production project"
# Secrets must be staging/test values (checked, never printed).
s=$(firebase functions:secrets:access STRIPE_SECRET --project $P 2>/dev/null | tail -1)
case "$s" in sk_test_*|rk_test_*) ;; *) unset s; fail "STRIPE_SECRET in $P is not a test key";; esac; unset s
a=$(firebase functions:secrets:access AGORA_APP_ID --project $P 2>/dev/null | tail -1 | tr -d '[:space:]')
[ -n "$a" ] && [ "$a" != "$PROD_AGORA_APP_ID" ] || { unset a; fail "AGORA_APP_ID in $P is empty or the production app"; }; unset a
gcloud storage buckets describe "gs://$P.firebasestorage.app" >/dev/null 2>&1 \
  || fail "Storage bucket for $P does not exist (Firebase console > Storage > Get started)"
echo "isolation checks passed for $P (${#FUNCS[@]} functions)"
[ "$MODE" = deploy ] || exit 0

LIST=$(printf 'functions:%s,' "${FUNCS[@]}"); LIST=${LIST%,}
firebase deploy --project "$P" --only firestore:indexes
firebase deploy --project "$P" --only firestore:rules,storage,hosting
firebase deploy --project "$P" --only "$LIST"
firebase functions:list --project "$P"
