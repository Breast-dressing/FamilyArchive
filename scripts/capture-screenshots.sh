#!/usr/bin/env bash
#
# Capture one screenshot per app page on a booted iOS simulator.
#
# Runs on macOS with Xcode 27. The GitHub Actions "Capture Screenshots" workflow
# uses this script on the xcode-27 runner. It builds the app for the simulator,
# installs/launches it, drives the real UI with XcodeBuildMCP, and saves PNGs to:
#
#   artifacts/screenshots/<timestamp>/
#   artifacts/screenshots-<timestamp>.zip
#
# Page inventory (derived from the SwiftUI navigation code):
#   01 Feed
#   02 Video
#   03 Music (Music section)
#   04 Archive (Music -> Archive)
#   05 More
#   06 + options on Archive
#   07 Family detail (reached through the real + -> Family flow with a sample URL)
#   08 + placeholder on Feed
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PROJECT="${PROJECT:-FamilyArchive/FamilyArchive.xcodeproj}"
SCHEME="${SCHEME:-FamilyArchive}"
BUNDLE_ID="${BUNDLE_ID:-com.example.FamilyArchive}"
DEVICE_NAME="${DEVICE_NAME:-iPhone 18 Pro}"
IOS_VERSION="${IOS_VERSION:-27.0}"
MCP_VERSION="${MCP_VERSION:-2.7.0}"

TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUT_DIR="$ROOT/artifacts/screenshots/$TS"
ZIP_PATH="$ROOT/artifacts/screenshots-$TS.zip"
BUILD_DIR="$ROOT/build/screenshots"
DERIVED_DATA="$BUILD_DIR/DerivedData"
APP_PATH="$DERIVED_DATA/Build/Products/Debug-iphonesimulator/$SCHEME.app"
SNAP="$(mktemp)"
MCP=(npx --yes "xcodebuildmcp@$MCP_VERSION" ui-automation)
FAILED=()

mkdir -p "$OUT_DIR" "$BUILD_DIR"
cleanup() { rm -f "$SNAP"; }
trap cleanup EXIT

if ! command -v xcrun >/dev/null 2>&1; then
  echo "error: xcrun not found. Run this on macOS with Xcode 27, or use the Capture Screenshots workflow." >&2
  exit 1
fi

echo "==> Xcode"
xcodebuild -version

echo "==> Building $SCHEME for the simulator"
xcodebuild build \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Debug \
  -destination "platform=iOS Simulator,name=$DEVICE_NAME,OS=$IOS_VERSION" \
  -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGNING_ALLOWED=NO \
  2>&1 | tee "$BUILD_DIR/xcodebuild-build.log"

if [[ ! -d "$APP_PATH" ]]; then
  echo "error: app not found at $APP_PATH" >&2
  exit 1
fi

echo "==> Resolving simulator: $DEVICE_NAME / iOS $IOS_VERSION"
UDID="$(xcrun simctl list devices available --json | python3 - "$DEVICE_NAME" "$IOS_VERSION" <<'PY'
import json
import sys

name, version = sys.argv[1], sys.argv[2]
label = "iOS-" + version.replace(".", "-")
devices_by_runtime = json.load(sys.stdin)["devices"]
for runtime, devices in devices_by_runtime.items():
    runtime_label = runtime.rsplit(".", 1)[-1]
    if runtime_label == label or runtime_label.startswith(label + "-"):
        for device in devices:
            if device["name"] == name:
                print(device["udid"])
                raise SystemExit(0)
raise SystemExit("simulator not found: %s / iOS %s" % (name, version))
PY
)"
echo "    UDID: $UDID"

xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b
xcrun simctl install "$UDID" "$APP_PATH"
xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl launch "$UDID" "$BUNDLE_ID" >/dev/null
"${MCP[@]}" wait-for-ui --simulator-id "$UDID" --predicate settled >/dev/null 2>&1 || true

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

snapshot() {
  "${MCP[@]}" snapshot-ui --simulator-id "$UDID" --output json \
    > "$SNAP" 2>>"$OUT_DIR/mcp.log"
}

find_ref() {
  python3 - "$SNAP" "$1" <<'PY'
import json
import sys

path, want = sys.argv[1], sys.argv[2]
try:
    data = json.load(open(path))
except Exception:
    raise SystemExit(1)

capture = (data.get("data") or {}).get("capture") or {}
entries = []
for kind in ("targets", "text"):
    for line in capture.get(kind, []) or []:
        parts = line.split("|")
        if len(parts) < 4:
            continue
        label = parts[3].strip()
        entries.append((0 if kind == "targets" else 1, parts[0], label))

exact = [entry for entry in entries if entry[2] == want]
if exact:
    print(exact[0][1])
    raise SystemExit(0)

partial = [entry for entry in entries if want in entry[2]]
if partial:
    partial.sort()
    print(partial[0][1])
    raise SystemExit(0)

raise SystemExit(1)
PY
}

wait_for() {
  local label="$1"
  local tries="${2:-45}"
  local i
  for ((i = 0; i < tries; i++)); do
    if snapshot && find_ref "$label" >/dev/null; then
      return 0
    fi
    sleep 1
  done
  return 1
}

tap_label() {
  local label="$1"
  local i ref
  for ((i = 0; i < 3; i++)); do
    if snapshot && ref=$(find_ref "$label"); then
      if "${MCP[@]}" tap --simulator-id "$UDID" --element-ref "$ref" >/dev/null 2>&1; then
        return 0
      fi
    fi
    sleep 1
  done
  return 1
}

shot() {
  local name="$1"
  xcrun simctl io "$UDID" screenshot "$OUT_DIR/$name.png"
  if [[ ! -s "$OUT_DIR/$name.png" ]]; then
    echo "error: screenshot is empty: $name" >&2
    return 1
  fi
  echo "    captured $name.png"
}

record_failure() {
  FAILED+=("$1")
  echo "    FAILED: $1" >&2
}

capture_page() {
  local file="$1"
  local label="$2"
  if wait_for "$label" 90; then
    shot "$file" || record_failure "$file"
  else
    record_failure "$file (missing '$label')"
  fi
}

handle_paste_prompt() {
  local i ref prompt
  for ((i = 0; i < 25; i++)); do
    if snapshot; then
      for prompt in "Allow Paste" "Allow" "允许粘贴"; do
        if ref=$(find_ref "$prompt"); then
          echo "    paste prompt: tapping '$prompt'"
          "${MCP[@]}" tap --simulator-id "$UDID" --element-ref "$ref" >/dev/null 2>&1 || true
          return 0
        fi
      done
      if find_ref "987654321" >/dev/null; then
        return 0
      fi
    fi
    sleep 1
  done
  return 1
}

# ---------------------------------------------------------------------------
# Pages
# ---------------------------------------------------------------------------

echo "==> 01 Feed"
capture_page "01-feed" "The Feed page"

echo "==> 02 Video"
if tap_label "Video"; then
  capture_page "02-video" "The Video page"
else
  record_failure "02-video (Video tab tap failed)"
fi

echo "==> 03 Music"
if tap_label "Music"; then
  capture_page "03-music" "Switch to Archive"
else
  record_failure "03-music (Music tab tap failed)"
fi

echo "==> 04 Archive"
if tap_label "Archive"; then
  capture_page "04-archive" "Badges"
else
  record_failure "04-archive (Archive segment tap failed)"
fi

echo "==> 05 More"
if tap_label "More"; then
  capture_page "05-more" "The More page"
else
  record_failure "05-more (More tab tap failed)"
fi

echo "==> 06 + options on Archive"
if tap_label "Music"; then
  if ! wait_for "Badges" 30; then
    tap_label "Archive" || true
  fi
  if tap_label "＋"; then
    capture_page "06-plus-archive" "Done"
  else
    record_failure "06-plus-archive (plus tab tap failed)"
  fi
else
  record_failure "06-plus-archive (Music tab tap failed)"
fi

echo "==> 07 Family detail (real + -> Family flow with a sample family URL)"
FAMILY_URL="https://i2.y.qq.com/?family_id=987654321"
printf '%s' "$FAMILY_URL" > "$OUT_DIR/family-url.txt"
if ! xcrun simctl pbcopy "$UDID" < "$OUT_DIR/family-url.txt" 2>/dev/null; then
  xcrun simctl pbcopy "$UDID" "$OUT_DIR/family-url.txt" || true
fi

if tap_label "Family"; then
  handle_paste_prompt || true
  if wait_for "987654321" 120; then
    if tap_label "987654321"; then
      capture_page "07-family-detail" "records"
    else
      record_failure "07-family-detail (family row tap failed)"
    fi
  else
    record_failure "07-family-detail (family row did not appear; clipboard/paste may have been blocked)"
  fi
else
  record_failure "07-family-detail (Family option tap failed)"
fi

echo "==> 08 + placeholder on Feed"
xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl launch "$UDID" "$BUNDLE_ID" >/dev/null
if wait_for "The Feed page" 90; then
  if tap_label "＋"; then
    capture_page "08-plus-placeholder" "No actions here"
  else
    record_failure "08-plus-placeholder (plus tab tap failed)"
  fi
else
  record_failure "08-plus-placeholder (app did not return to Feed)"
fi

# ---------------------------------------------------------------------------
# Manifest and zip
# ---------------------------------------------------------------------------

{
  echo "timestamp: $TS"
  echo "simulator: $DEVICE_NAME / iOS $IOS_VERSION"
  echo "udid: $UDID"
  echo "bundle: $BUNDLE_ID"
  echo "screenshots:"
  shopt -s nullglob
  for file in "$OUT_DIR"/*.png; do
    printf '  %s (%s bytes)\n' "$(basename "$file")" "$(wc -c < "$file" | tr -d ' ')"
  done
} > "$OUT_DIR/manifest.txt"

cat "$OUT_DIR/manifest.txt"
( cd "$ROOT/artifacts/screenshots" && zip -qry "$ZIP_PATH" "$TS" )
echo "==> Screenshot folder: $OUT_DIR"
echo "==> Screenshot zip:    $ZIP_PATH"

if (( ${#FAILED[@]} > 0 )); then
  printf '==> INCOMPLETE: %s\n' "${FAILED[@]}" >&2
  exit 1
fi

echo "==> All requested screenshots captured."
