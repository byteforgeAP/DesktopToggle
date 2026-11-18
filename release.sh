#!/bin/bash
# Builds the universal app and zips it for a GitHub Release.
set -euo pipefail
cd "$(dirname "$0")"

./build.sh

VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Resources/Info.plist)"
ZIP="build/DesktopToggle-$VERSION.zip"
rm -f "$ZIP"
ditto -c -k --keepParent build/DesktopToggle.app "$ZIP"

echo "Release zip: $ZIP"
echo "Publish it with: gh release create v$VERSION $ZIP --title \"DesktopToggle $VERSION\" --generate-notes"
