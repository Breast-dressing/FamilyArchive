#!/usr/bin/env bash
# Capture the two review screenshots on the pinned iPhone 18 Pro simulator.
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
MCP=(npx --yes xcodebuildmcp@2.7.0 ui-automation)
SNAP="$(mktemp)"

cleanup() { rm -f "$SNAP"; }
trap cleanup EXIT

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
xcrun simctl bootstatus "$UDID" -b
xcrun simctl install "$UDID" "$APP"
xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl launch "$UDID" "$BUNDLE_ID" -UIPreviewSeed >/dev/null
"${MCP[@]}" wait-for-ui --simulator-id "$UDID" --predicate settled >/dev/null 2>&1 || true

snapshot() {
  "${MCP[@]}" snapshot-ui --simulator-id "$UDID" --output json > "$SNAP" 2>/dev/null
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
    "${MCP[@]}" tap --simulator-id "$UDID" --element-ref "$ref" >/dev/null 2>&1
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

echo "==> Music tab"
tap_label "音乐" || { echo "error: music tab not found" >&2; exit 1; }
wait_for "家族信息" 20 || true
tap_label "我的" || { echo "error: 我的 tab not found" >&2; exit 1; }
wait_for "家族信息" 30 || { echo "error: family grid not found" >&2; exit 1; }
xcrun simctl io "$UDID" screenshot "$ROOT/music_tab_ui.png"

echo "==> Family detail"
tap_label "jaychou" || { echo "error: family card not found" >&2; exit 1; }
wait_for "成员列表" 30 || { echo "error: family detail not found" >&2; exit 1; }
xcrun simctl io "$UDID" screenshot "$ROOT/family_detail_ui.png"

echo "==> Screenshots:"
ls -lh "$ROOT/music_tab_ui.png" "$ROOT/family_detail_ui.png"
