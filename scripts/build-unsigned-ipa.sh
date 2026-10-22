#!/usr/bin/env bash
#
# Build an unsigned IPA for FamilyArchive.
#
# Requirements: macOS with Xcode 27 (or the GitHub Actions "Build Unsigned IPA"
# workflow, which uses the xcode-27 runner). No signing identity or team is
# needed; this script deliberately disables code signing.
#
# Output:
#   build/unsigned/FamilyArchive.ipa
#   build/unsigned/FamilyArchive.xcarchive
#   build/unsigned/xcodebuild-archive.log
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PROJECT="${PROJECT:-FamilyArchive/FamilyArchive.xcodeproj}"
SCHEME="${SCHEME:-FamilyArchive}"
CONFIGURATION="${CONFIGURATION:-Release}"
OUTPUT_DIR="${OUTPUT_DIR:-build/unsigned}"
ARCHIVE_PATH="$OUTPUT_DIR/FamilyArchive.xcarchive"
DERIVED_DATA="$OUTPUT_DIR/DerivedData"
IPA_PATH="$OUTPUT_DIR/FamilyArchive.ipa"

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "error: xcodebuild not found. Run this on macOS with Xcode 27, or use the Build Unsigned IPA workflow." >&2
  exit 1
fi

rm -rf "$ARCHIVE_PATH" "$DERIVED_DATA" "$OUTPUT_DIR/Payload" "$IPA_PATH"
mkdir -p "$OUTPUT_DIR"

echo "==> Archiving $SCHEME (unsigned, generic/platform=iOS)"
xcodebuild archive \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination "generic/platform=iOS" \
  -archivePath "$ARCHIVE_PATH" \
  -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGN_ENTITLEMENTS="" \
  DEVELOPMENT_TEAM="" \
  PROVISIONING_PROFILE_SPECIFIER="" \
  2>&1 | tee "$OUTPUT_DIR/xcodebuild-archive.log"

APPS_DIR="$ARCHIVE_PATH/Products/Applications"
shopt -s nullglob
apps=("$APPS_DIR"/*.app)
if (( ${#apps[@]} == 0 )); then
  echo "error: no .app found in $APPS_DIR" >&2
  exit 1
fi
APP_PATH="${apps[0]}"

echo "==> Packaging unsigned IPA"
mkdir -p "$OUTPUT_DIR/Payload"
cp -R "$APP_PATH" "$OUTPUT_DIR/Payload/"
( cd "$OUTPUT_DIR" && zip -qry "$(basename "$IPA_PATH")" Payload )

if [[ ! -s "$IPA_PATH" ]]; then
  echo "error: IPA was not created or is empty: $IPA_PATH" >&2
  exit 1
fi

echo "==> Unsigned IPA ready"
echo "    IPA:  $IPA_PATH"
echo "    App:  $APP_PATH"
echo "    Size: $(wc -c < "$IPA_PATH" | tr -d ' ') bytes"
echo "    Note: unsigned; do not upload to TestFlight/App Store without signing."
