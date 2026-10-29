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
xcrun simctl spawn "$UDID" defaults write com.apple.keyboard.preferences DidShowContinuousPathIntroduction -bool true 2>/dev/null || true
xcrun simctl spawn "$UDID" defaults write com.apple.keyboard.preferences DidShowGestureKeyboardIntroduction -bool true 2>/dev/null || true
xcrun simctl install "$UDID" "$APP"
xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true

rm -f "$ROOT"/*.png

CONTAINER="$(xcrun simctl get_app_container "$UDID" "$BUNDLE_ID" data)"
READY_FILE="$CONTAINER/Documents/UIPreviewReady"

launch() {
  local label="$1"
  shift
  xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
  rm -f "$READY_FILE"
  xcrun simctl launch "$UDID" "$BUNDLE_ID" -UIPreviewSeed "$@" >/dev/null
  local i
  for ((i = 0; i < 40; i++)); do
    if [[ -f "$READY_FILE" ]]; then
      break
    fi
    sleep 1
  done
  if [[ ! -f "$READY_FILE" ]]; then
    echo "warning: readiness marker not written for $label" >&2
  fi
  sleep 2
  echo "==> $label"
}

shot() {
  xcrun simctl io "$UDID" screenshot "$ROOT/$1"
  echo "    captured $1"
}

# Custom bottom toolbar states.
launch "Music root (search + date + plus)" -UIPreviewMusic
shot music_tab_ui.png

launch "My page sections" -UIPreviewMusic
shot my_page_sections_ui.png

launch "Fans skins" -UIPreviewFans
sleep 1
shot fans_ui.png

launch "Medal hall" -UIPreviewMedals
sleep 1
shot medals_ui.png

launch "Lyric cards" -UIPreviewCards
sleep 1
shot cards_ui.png

# Secondary pages: the native tab bar hides, and the floating bar follows the
# freed safe area down to the bottom of the screen instead of leaving with it.
launch "Family detail (tab bar hidden)" -UIPreviewFamily
shot family_detail_ui.png

launch "Member detail (tab bar hidden)" -UIPreviewMember
shot member_detail_ui.png

# Feed toolbar: search capsule + date circle + plus circle.
launch "Feed toolbar" -UIPreviewFeed
shot feed_tab_ui.png

# Feed search: in-place long search bar + date icon + plus.
launch "Feed search toolbar" -UIPreviewFeedSearch
shot feed_search_ui.png

launch "Feed search focused" -UIPreviewSearchFocus
sleep 4
shot feed_search_focused_ui.png

launch "Video toolbar (search + date + plus)" -UIPreviewVideo
shot video_tab_ui.png

launch "More (detached tab, no toolbar)" -UIPreviewMore
shot more_tab_ui.png

# Floating bar exit: the review curve is stretched to 3s so two stills land
# between the end states. The bar must be lower and fainter in the second one —
# identical frames would mean it jumped instead of travelling.
launch "Floating bar exit mid-flight" -UIPreviewBarExit
shot bar_exit_a_ui.png
shot bar_exit_b_ui.png

# Date filter and plus use the same sheet API and animation.
launch "Date filter sheet" -UIPreviewDateSheet
sleep 3
shot date_filter_sheet_ui.png

launch "Feed plus sheet" -UIPreviewFeedPlus
sleep 3
shot feed_plus_sheet_ui.png

# Accounts sheet: presented from the 动态 NavigationBar button, so the zoom
# transition is anchored on that button instead of the sheet's default origin.
launch "Feed accounts sheet" -UIPreviewAccounts
sleep 3
shot accounts_sheet_ui.png

launch "Music plus sheet" -UIPreviewMusicPlus
sleep 3
shot music_plus_sheet_ui.png

# System share sheet for the family share button.
launch "Family share sheet" -UIPreviewFamily -UIPreviewShare
sleep 5
shot share_sheet_ui.png

# Family honor image export produced by the custom "图片" action renderer.
rm -f "$CONTAINER/Documents/family-honor-export.png"
launch "Family honor image export" -UIPreviewFamily -UIPreviewShareImage
for ((i = 0; i < 15; i++)); do
  if [[ -f "$CONTAINER/Documents/family-honor-export.png" ]]; then break; fi
  sleep 1
done
cp "$CONTAINER/Documents/family-honor-export.png" "$ROOT/family_honor_export.png"
echo "    captured family_honor_export.png"

# Lifecycle tour: member -> family -> archive, driven by the real NavigationStack
# path. Timers inside the app run at 5s and 10s after appearing.
launch "Accessory lifecycle tour" -UIPreviewTour
shot tour_member_ui.png
sleep 5
shot tour_family_ui.png
sleep 5
shot tour_archive_ui.png

echo "==> Screenshots:"
ls -lh "$ROOT"/*.png
