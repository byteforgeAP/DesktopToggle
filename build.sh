#!/bin/bash
# Builds build/DesktopToggle.app from Sources/ and Resources/.
set -euo pipefail
cd "$(dirname "$0")"

APP="build/DesktopToggle.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"

swiftc -O Sources/main.swift -o "$APP/Contents/MacOS/DesktopToggle"
cp Resources/Info.plist "$APP/Contents/Info.plist"
# iCloud-synced folders (like the Desktop) add extended attributes that codesign rejects.
xattr -cr "$APP"
codesign --force --sign - "$APP" >/dev/null 2>&1

echo "Built $APP"
