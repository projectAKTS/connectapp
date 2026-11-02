#!/bin/bash
# Builds the app against the STAGING Firebase project (helperly-call-v2-dev).
#   tool/build_staging.sh android        -> debug APK
#   tool/build_staging.sh ios            -> release iOS build for a cable install
#   Extra flutter build arguments may follow, e.g. --dart-define=ENABLE_RUNTIME_DIAG=true
# Staging configs live in config/staging/ (git-ignored). The production
# native configs are restored on exit, even on failure.
set -euo pipefail
ROOT=$(git rev-parse --show-toplevel); cd "$ROOT"
PLATFORM=${1:-android}
shift || true
STAGING_PROJECT=helperly-call-v2-dev
PROD_PROJECT=connectapp-278b4
CFG=config/staging

python3 - "$CFG" "$STAGING_PROJECT" "$PROD_PROJECT" <<'PY'
import json, plistlib, sys
cfg, staging, prod = sys.argv[1:4]
g = json.load(open(f"{cfg}/google-services.json"))["project_info"]["project_id"]
p = plistlib.load(open(f"{cfg}/GoogleService-Info.plist", "rb"))["PROJECT_ID"]
e = json.load(open(f"{cfg}/firebase.env.json"))
ok = g == p == e["STAGING_PROJECT_ID"] == staging and e["HELPERLY_ENV"] == "staging"
ok = ok and prod not in (g, p, e["STAGING_PROJECT_ID"])
print(f"staging config: android={g} ios={p} defines={e['STAGING_PROJECT_ID']}")
sys.exit(0 if ok else "staging config does not point only at the staging project")
PY

BACKUP=$(mktemp -d)
cp android/app/google-services.json "$BACKUP/"
cp ios/Runner/GoogleService-Info.plist "$BACKUP/"
restore() {
  cp "$BACKUP/google-services.json" android/app/google-services.json
  cp "$BACKUP/GoogleService-Info.plist" ios/Runner/GoogleService-Info.plist
  git diff --quiet -- android/app/google-services.json ios/Runner/GoogleService-Info.plist \
    && echo "production native configs restored"
}
trap restore EXIT
cp "$CFG/google-services.json" android/app/google-services.json
cp "$CFG/GoogleService-Info.plist" ios/Runner/GoogleService-Info.plist

DEFINES=(--dart-define-from-file="$CFG/firebase.env.json" "$@")
if [ "$PLATFORM" = android ]; then
  flutter build apk --debug "${DEFINES[@]}"
  APK=build/app/outputs/flutter-apk/app-debug.apk
  RES=$(unzip -p "$APK" resources.arsc | LC_ALL=C grep -a -o "$STAGING_PROJECT\|$PROD_PROJECT" | sort -u)
  if [ "$RES" = "$STAGING_PROJECT" ]; then
    echo "APK native config: $STAGING_PROJECT only"
  else
    echo "APK native config is not staging-only: $RES" >&2; exit 1
  fi
else
  # Release: a debug build does not start from the home screen and gets no
  # VoIP pushes while killed. Development APNs suits a cable install.
  FLUTTER_XCODE_APS_ENVIRONMENT=development flutter build ios --release "${DEFINES[@]}"
  PID=$(/usr/libexec/PlistBuddy -c 'Print :PROJECT_ID' build/ios/iphoneos/Runner.app/GoogleService-Info.plist)
  if [ "$PID" = "$STAGING_PROJECT" ]; then
    echo "iOS app config: $STAGING_PROJECT only"
  else
    echo "iOS app config is not staging-only: $PID" >&2; exit 1
  fi
fi
