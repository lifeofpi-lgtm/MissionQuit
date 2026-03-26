#!/bin/bash
set -e

cd "$(dirname "$0")"

echo "🔨 Building MissionQuit..."
swift build

APP_DIR="MissionQuit.app/Contents/MacOS"
RES_DIR="MissionQuit.app/Contents/Resources"
mkdir -p "$APP_DIR" "$RES_DIR"
cp .build/debug/MissionQuit "$APP_DIR/MissionQuit"
cp Info.plist MissionQuit.app/Contents/Info.plist
cp AppIcon.icns "$RES_DIR/AppIcon.icns"

echo "✅ Built MissionQuit.app"

if [ "$1" = "--install" ]; then
    # Install to /Applications and code-sign in place with persistent identity
    rm -rf /Applications/MissionQuit.app
    cp -R MissionQuit.app /Applications/MissionQuit.app
    xattr -cr /Applications/MissionQuit.app
    codesign --force --deep --sign "MissionQuit Dev" /Applications/MissionQuit.app
    echo "🔏 Code-signed (MissionQuit Dev)"
    echo "📦 Installed to /Applications/MissionQuit.app"
    echo ""
    echo "⚠️  Grant Accessibility permission in System Settings if this is the first install."
    echo "To run:  open /Applications/MissionQuit.app"
else
    echo ""
    echo "Dev mode — run from Terminal:"
    echo "  .build/debug/MissionQuit"
    echo ""
    echo "To install to /Applications:  bash build.sh --install"
fi
