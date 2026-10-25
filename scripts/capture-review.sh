#!/usr/bin/env bash
# Capture the review screenshots on the pinned iPhone 18 Pro simulator.
#
# The app exposes DEBUG-only launch routes (-UIPreview*) that drive the exact
# same router state as real pushes and pops. That keeps the review deterministic
# and avoids slow/fragile accessibility snapshots in CI.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PROJECT="FamilyArchive/FamilyArchive.xcodeproj"
SCHEME="FamilyArchive"
BUNDLE_ID="com.example.FamilyArchive"
DEVICE_NAME="iPhone 18 Pro"
IOS_VERSION="27.0"
DERIVED_DATA="$ROOT/build/review/DerivedData"
APP="$DERIVED_DATA/Build/Products/Debug-iphonesimulator/$SCHEME.app"

run_with_timeout() {
  local secs="$1"
  shift
  python3 - "$secs" "$@" <<'PY'
import os, signal, subprocess, sys
secs = float(sys.argv[1])
cmd = sys.argv[2:]
process = subprocess.Popen(cmd, start_new_session=True)
try:
    rc = process.wait(timeout=secs)
except subprocess.TimeoutExpired:
    try:
        os.killpg(process.pid, signal.SIGKILL)
    except ProcessLookupError:
        pass
    process.wait()
    raise SystemExit(124)
raise SystemExit(rc)
PY
}

if ! command -v xcrun >/dev/null 2>&1; then
  echo "error: xcrun not found" >&2
  exit 1
fi

mkdir -p "$ROOT/build"
echo "==> Building $SCHEME for simulator"
xcodebuild build \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Debug \
  -destination "platform=iOS Simulator,name=$DEVICE_NAME,OS=$IOS_VERSION" \
  -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGNING_ALLOWED=NO \
  2>&1 | tee "$ROOT/build/review-xcodebuild.log"

UDID="$(xcrun simctl list devices available --json | python3 -c '
import json, sys
data = json.load(sys.stdin)["devices"]
for runtime, devices in data.items():
    for device in devices:
        if device["name"] == "iPhone 18 Pro":
            print(device["udid"])
            raise SystemExit(0)
raise SystemExit(1)
' || true)"
if [[ -z "$UDID" ]]; then
  echo "error: simulator not found" >&2
  exit 1
fi
echo "==> Simulator: $UDID"

xcrun simctl boot "$UDID" 2>/dev/null || true
run_with_timeout 600 xcrun simctl bootstatus "$UDID" -b
xcrun simctl install "$UDID" "$APP"
xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true

rm -f "$ROOT"/*.png

launch() {
  local label="$1"
  shift
  xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
  xcrun simctl launch "$UDID" "$BUNDLE_ID" -UIPreviewSeed "$@" >/dev/null
  echo "==> $label"
}

shot() {
  xcrun simctl io "$UDID" screenshot "$ROOT/$1"
  echo "    captured $1"
}

# Music root: search accessory, archive section.
launch "Music root (search accessory)" -UIPreviewMusic
sleep 3
shot music_tab_ui.png

# Family detail: date filter + pending files accessory.
launch "Family detail (date + pending accessory)" -UIPreviewFamily -UIPreviewPending
sleep 3
shot family_detail_ui.png

# Member detail: date filter accessory must still be present.
launch "Member detail" -UIPreviewMember
sleep 3
shot member_detail_ui.png

# App Store style date sheet: opaque adaptive background.
launch "Date filter sheet" -UIPreviewDateSheet
sleep 3.5
shot date_filter_sheet_ui.png

# App Store style pending files sheet: opaque adaptive background.
launch "Pending files sheet" -UIPreviewPendingSheet
sleep 3.5
shot pending_files_sheet_ui.png

# Per-tab accessory content.
launch "Feed accessory" -UIPreviewFeed
sleep 3
shot feed_tab_ui.png

launch "Video accessory" -UIPreviewVideo
sleep 3
shot video_tab_ui.png

launch "More (no accessory)" -UIPreviewMore
sleep 3
shot more_tab_ui.png

# Lifecycle tour: member -> family -> archive, driven by the real NavigationStack
# path. Timers inside the app run at 4s and 8s after launch.
launch "Accessory lifecycle tour" -UIPreviewTour
sleep 2.5
shot tour_member_ui.png
sleep 3.5
shot tour_family_ui.png
sleep 4
shot tour_archive_ui.png

echo "==> Screenshots:"
ls -lh "$ROOT"/*.png
