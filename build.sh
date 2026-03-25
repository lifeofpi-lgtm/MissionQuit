#!/bin/bash
set -e

cd "$(dirname "$0")"

echo "🔨 Building MissionQuit..."
swift build

APP_DIR="MissionQuit.app/Contents/MacOS"
mkdir -p "$APP_DIR"
cp .build/debug/MissionQuit "$APP_DIR/MissionQuit"
cp Info.plist MissionQuit.app/Contents/Info.plist

echo "✅ Built MissionQuit.app"
echo ""
echo "To run:  open MissionQuit.app"
echo "You'll be prompted to grant Accessibility permission in System Settings."
