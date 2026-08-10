#!/bin/zsh

set -euo pipefail

PROJECT_ROOT="${0:A:h:h}"
APP_ROOT="$PROJECT_ROOT/dist/CleanMyScreen.app"
OUTPUT_ROOT="$PROJECT_ROOT/dist/releases"
STAGING_ROOT="$(mktemp -d /tmp/cleanmyscreen-dmg.XXXXXX)"

if [[ ! -d "$APP_ROOT" ]]; then
    echo "Build the app first with ./Scripts/build-app.sh" >&2
    exit 1
fi

mkdir -p "$OUTPUT_ROOT"

for architecture in arm64 x86_64; do
    volume_name="CleanMyScreen-${architecture}"
    image_root="$STAGING_ROOT/$architecture"
    app_copy="$image_root/CleanMyScreen.app"
    mkdir -p "$image_root"
    ditto --noextattr --noqtn "$APP_ROOT" "$app_copy"

    universal_binary="$app_copy/Contents/MacOS/CleanMyScreen"
    thin_binary="$STAGING_ROOT/CleanMyScreen-${architecture}"
    lipo -thin "$architecture" "$universal_binary" -output "$thin_binary"
    cp "$thin_binary" "$universal_binary"

    xattr -cr "$app_copy"
    codesign --force --deep --sign - "$app_copy"
    codesign --verify --deep --strict "$app_copy"
    ln -s /Applications "$image_root/Applications"

    output_path="$OUTPUT_ROOT/${volume_name}.dmg"
    hdiutil create -volname "$volume_name" -srcfolder "$image_root" -format UDZO -ov "$output_path" >/dev/null
    hdiutil verify "$output_path" >/dev/null
    echo "$output_path"
done
