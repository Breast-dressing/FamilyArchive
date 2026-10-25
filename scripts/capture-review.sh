#!/usr/bin/env bash
# Capture the review screenshots on the pinned iPhone 18 Pro simulator and
# exercise the bottom accessory lifecycle end to end.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PROJECT="FamilyArchive/FamilyArchive.xcodeproj"
SCHEME="FamilyArchive"
BUNDLE_ID="com.example.FamilyArchive"
DEVICE_NAME="iPhone 18 Pro"
IOS_VERSION="27.0"
SCREEN_WIDTH=402
SCREEN_HEIGHT=874
DERIVED_DATA="$ROOT/build/review/DerivedData"
APP="$DERIVED_DATA/Build/Products/Debug-iphonesimulator/$SCHEME.app"
MCP=(npx --yes xcodebuildmcp@2.7.0 ui-automation)
SNAP="$(mktemp)"

cleanup() { rm -f "$SNAP"; }
trap cleanup EXIT

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
xcrun simctl launch "$UDID" "$BUNDLE_ID" \
  -UIPreviewSeed -UIPreviewArchive -UIPreviewPending >/dev/null
run_with_timeout 90 "${MCP[@]}" wait-for-ui --simulator-id "$UDID" --predicate settled >/dev/null 2>&1 || true

snapshot() {
  run_with_timeout 60 "${MCP[@]}" snapshot-ui --simulator-id "$UDID" --output json > "$SNAP" 2>/dev/null
}

find_ref() {
  python3 - "$SNAP" "$1" <<'PY'
import json, sys
path, want = sys.argv[1], sys.argv[2]
try:
    data = json.load(open(path))
except Exception:
    raise SystemExit(1)
capture = (data.get("data") or {}).get("capture") or {}
for kind in ("targets", "text"):
    for line in capture.get(kind, []) or []:
        parts = line.split("|")
        if len(parts) < 4:
            continue
        if kind == "targets" and parts[1] != "tap":
            continue
        label = parts[3].strip()
        if label == want or want in label:
            print(parts[0])
            raise SystemExit(0)
raise SystemExit(1)
PY
}

tap_label() {
  local label="$1"
  local ref
  if snapshot && ref=$(find_ref "$label"); then
    run_with_timeout 30 "${MCP[@]}" tap --simulator-id "$UDID" --element-ref "$ref" >/dev/null 2>&1
    sleep 1
    return 0
  fi
  return 1
}

wait_for() {
  local label="$1"
  local tries="${2:-30}"
  local i
  for ((i = 0; i < tries; i++)); do
    if snapshot && find_ref "$label" >/dev/null; then
      return 0
    fi
    sleep 1
  done
  return 1
}

swipe_back() {
  run_with_timeout 30 "${MCP[@]}" gesture \
    --simulator-id "$UDID" \
    --preset swipe-from-left-edge \
    --screen-width "$SCREEN_WIDTH" \
    --screen-height "$SCREEN_HEIGHT" \
    --duration 0.3 >/dev/null 2>&1
  sleep 1.5
}

shot() {
  xcrun simctl io "$UDID" screenshot "$ROOT/$1"
  echo "    captured $1"
}

echo "==> Music root (archive default, search accessory)"
tap_label "音乐" || { echo "error: music tab not found" >&2; exit 1; }
wait_for "家族信息" 45 || { echo "error: family grid not found" >&2; exit 1; }
shot music_tab_ui.png

echo "==> Family detail (date + pending accessory)"
tap_label "jaychou" || { echo "error: family card not found" >&2; exit 1; }
wait_for "Tong" 45 || { echo "error: family detail not found" >&2; exit 1; }
shot family_detail_ui.png

echo "==> Member detail"
tap_label "Tong" || { echo "error: member row not found" >&2; exit 1; }
wait_for "总荣誉" 45 || { echo "error: member detail not found" >&2; exit 1; }
shot member_detail_ui.png

echo "==> Back to family detail (accessory must stay in date form)"
swipe_back
wait_for "Tong" 45 || { echo "error: family detail did not return" >&2; exit 1; }
shot family_return_ui.png

echo "==> Date filter sheet"
tap_label "日期筛选" || { echo "error: date accessory not found" >&2; exit 1; }
wait_for "起始日期" 30 || { echo "error: date filter sheet not found" >&2; exit 1; }
shot date_filter_sheet_ui.png
tap_label "关闭" || { echo "error: date filter close button not found" >&2; exit 1; }
wait_for "Tong" 30 || { echo "error: date filter did not dismiss" >&2; exit 1; }

echo "==> Pending files sheet"
tap_label "待保存文件" || { echo "error: pending accessory not found" >&2; exit 1; }
wait_for "保存文件" 30 || { echo "error: pending sheet not found" >&2; exit 1; }
shot pending_files_sheet_ui.png
tap_label "关闭" || { echo "error: pending close button not found" >&2; exit 1; }
wait_for "Tong" 30 || { echo "error: pending sheet did not dismiss" >&2; exit 1; }

echo "==> Back to archive (search accessory)"
swipe_back
wait_for "家族信息" 45 || { echo "error: archive did not return" >&2; exit 1; }
shot archive_return_ui.png

echo "==> Feed tab accessory"
tap_label "动态" || { echo "error: feed tab not found" >&2; exit 1; }
wait_for "暂无动态" 30 || { echo "error: feed page not found" >&2; exit 1; }
shot feed_tab_ui.png

echo "==> Video tab accessory"
tap_label "影视" || { echo "error: video tab not found" >&2; exit 1; }
wait_for "暂无影视" 30 || { echo "error: video page not found" >&2; exit 1; }
shot video_tab_ui.png

echo "==> More tab (no accessory container)"
tap_label "更多" || { echo "error: more tab not found" >&2; exit 1; }
sleep 2
shot more_tab_ui.png

echo "==> Music tab again"
tap_label "音乐" || { echo "error: music tab not found" >&2; exit 1; }
wait_for "家族信息" 30 || { echo "error: archive did not return" >&2; exit 1; }
shot music_back_ui.png

echo "==> Screenshots:"
ls -lh "$ROOT"/*.png
