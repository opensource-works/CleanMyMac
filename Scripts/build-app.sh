#!/bin/zsh

set -euo pipefail

PROJECT_ROOT="${0:A:h:h}"
BUILD_CONFIGURATION="${1:-release}"
OUTPUT_ROOT="$PROJECT_ROOT/dist"
APP_ROOT="$OUTPUT_ROOT/CleanMyScreen.app"
ARM_TRIPLE="arm64-apple-macosx14.0"
INTEL_TRIPLE="x86_64-apple-macosx14.0"
STAGING_ROOT="$(mktemp -d /tmp/cleanmyscreen-build.XXXXXX)"
STAGED_APP="$STAGING_ROOT/CleanMyScreen.app"
CONTENTS_ROOT="$STAGED_APP/Contents"
MACOS_ROOT="$CONTENTS_ROOT/MacOS"
RESOURCES_ROOT="$CONTENTS_ROOT/Resources"

cleanup() {
    rm -rf "$STAGING_ROOT"
}
trap cleanup EXIT

cd "$PROJECT_ROOT"
swift build -c "$BUILD_CONFIGURATION" --triple "$ARM_TRIPLE" --product CleanMyScreen
swift build -c "$BUILD_CONFIGURATION" --triple "$INTEL_TRIPLE" --product CleanMyScreen

ARM_BIN="$(swift build -c "$BUILD_CONFIGURATION" --triple "$ARM_TRIPLE" --show-bin-path)/CleanMyScreen"
INTEL_BIN="$(swift build -c "$BUILD_CONFIGURATION" --triple "$INTEL_TRIPLE" --show-bin-path)/CleanMyScreen"

mkdir -p "$MACOS_ROOT"
lipo -create "$ARM_BIN" "$INTEL_BIN" -output "$MACOS_ROOT/CleanMyScreen"
cp "$PROJECT_ROOT/SupportingFiles/Info.plist" "$CONTENTS_ROOT/Info.plist"
mkdir -p "$RESOURCES_ROOT"
cp "$PROJECT_ROOT/SupportingFiles/AppIcon.icns" "$RESOURCES_ROOT/AppIcon.icns"

# Sign outside File Provider-managed folders, whose metadata can make codesign
# reject an otherwise clean bundle. Copy the signed result back without xattrs.
xattr -cr "$STAGED_APP"
codesign --force --deep --sign - "$STAGED_APP"
codesign --verify --deep --strict "$STAGED_APP"

if [[ -d "$APP_ROOT" ]]; then
    rm -rf "$APP_ROOT"
fi
mkdir -p "$OUTPUT_ROOT"
ditto --noextattr --noqtn "$STAGED_APP" "$APP_ROOT"
# Strip metadata in one pass immediately before verification. Removing
# File Provider attributes individually can cause FinderInfo to be re-applied
# between commands on synced workspace folders.
xattr -cr "$APP_ROOT"
codesign --verify --deep --strict "$APP_ROOT"

echo "$APP_ROOT"
