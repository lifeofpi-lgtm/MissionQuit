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
echo ""

# Install to /Applications
rm -rf /Applications/MissionQuit.app
cp -R MissionQuit.app /Applications/MissionQuit.app
echo "📦 Installed to /Applications/MissionQuit.app"
echo "To run:  open /Applications/MissionQuit.app"
