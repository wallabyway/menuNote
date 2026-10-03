#!/bin/bash
# menuNote build script — produces menuNote.app in ./build/
# Requires: macOS 14+, Xcode Command Line Tools (xcode-select --install)
set -euo pipefail
cd "$(dirname "$0")"

echo "==> Building (release)..."
swift build -c release

APP="build/menuNote.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

echo "==> Assembling bundle..."
cp .build/release/menuNote "$APP/Contents/MacOS/"
cp assets/Info.plist "$APP/Contents/Info.plist"

if [ -f assets/AppIcon.icns ]; then
    cp assets/AppIcon.icns "$APP/Contents/Resources/"
else
    echo "    (no AppIcon.icns found — running without custom icon)"
fi

echo "==> Code signing (ad-hoc)..."
codesign --force --sign - "$APP"

echo
echo "Done: $APP"
read -p "Install to /Applications? [y/N] " yn
if [[ "$yn" =~ ^[Yy]$ ]]; then
    rm -rf /Applications/menuNote.app
    cp -R "$APP" /Applications/
    echo "Installed. Launching..."
    open /Applications/menuNote.app
fi
