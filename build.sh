#!/bin/bash
# Builds build/DesktopToggle.app from Sources/ and Resources/.
set -euo pipefail
cd "$(dirname "$0")"

if ! command -v swiftc >/dev/null 2>&1; then
    echo "swiftc not found. Install the Xcode Command Line Tools first: xcode-select --install" >&2
    exit 1
fi

# Assemble and sign in a temp folder: iCloud-synced folders (like the Desktop) keep
# adding extended attributes that make codesign fail.
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
APP_STAGE="$STAGE/DesktopToggle.app"
mkdir -p "$APP_STAGE/Contents/MacOS"

# Universal binary: runs natively on Apple Silicon and Intel Macs.
for arch in arm64 x86_64; do
    swiftc -O -target "$arch-apple-macos13.0" Sources/main.swift -o "$STAGE/DesktopToggle-$arch"
done
lipo -create "$STAGE/DesktopToggle-arm64" "$STAGE/DesktopToggle-x86_64" \
     -output "$APP_STAGE/Contents/MacOS/DesktopToggle"
cp Resources/Info.plist "$APP_STAGE/Contents/Info.plist"
xattr -cr "$APP_STAGE"
codesign --force --sign - "$APP_STAGE" 2>&1 | grep -v "replacing existing signature" || true
codesign --verify "$APP_STAGE"

APP="build/DesktopToggle.app"
rm -rf "$APP"
mkdir -p build
ditto "$APP_STAGE" "$APP"

echo "Built $APP"
