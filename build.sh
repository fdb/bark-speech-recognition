#!/bin/zsh
# Builds and signs build/Bark.app. A stable signing identity keeps the Accessibility
# permission across rebuilds; set BARK_SIGN_IDENTITY to override.
cd "$(dirname "$0")"
set -euo pipefail

identity="${BARK_SIGN_IDENTITY:-Developer ID Application}"
app=build/Bark.app

swift build -c release
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp .build/release/Bark "$app/Contents/MacOS/Bark"
cp Resources/Info.plist "$app/Contents/Info.plist"
codesign --force --options runtime --entitlements Resources/Bark.entitlements --sign "$identity" "$app"
echo "Built $app"
