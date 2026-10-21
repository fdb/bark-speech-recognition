#!/bin/zsh
# Renders the SVGs in this folder into the app's resources:
#   Resources/AppIcon.icns            from bark-app-icon.svg
#   Resources/MenuBarIcon(@2x).png    from bark-menubar.svg (18 pt tall template image)
# Needs resvg (brew install resvg).
cd "$(dirname "$0")"
set -euo pipefail

iconset=$(mktemp -d)/AppIcon.iconset
mkdir -p "$iconset"
for size in 16 32 128 256 512; do
  resvg -w $size -h $size bark-app-icon.svg "$iconset/icon_${size}x${size}.png"
  resvg -w $((size * 2)) -h $((size * 2)) bark-app-icon.svg "$iconset/icon_${size}x${size}@2x.png"
done
iconutil -c icns "$iconset" -o ../Resources/AppIcon.icns

resvg -h 18 bark-menubar.svg ../Resources/MenuBarIcon.png
resvg -h 36 bark-menubar.svg ../Resources/MenuBarIcon@2x.png
echo "Wrote Resources/AppIcon.icns and Resources/MenuBarIcon(@2x).png"
