#!/bin/bash
# Builds the app, installs it to ~/Applications and starts it at every login.
set -euo pipefail
cd "$(dirname "$0")"

LABEL="io.github.byteforgeap.DesktopToggle"
OLD_LABEL="local.ayush.DesktopToggle" # used by versions before 1.0.1
DEST="$HOME/Applications/DesktopToggle.app"
AGENT="$HOME/Library/LaunchAgents/$LABEL.plist"

./build.sh

# Stop a running copy (and any old-label login item) before replacing it.
for l in "$LABEL" "$OLD_LABEL"; do
    launchctl bootout "gui/$(id -u)/$l" 2>/dev/null || true
done
rm -f "$HOME/Library/LaunchAgents/$OLD_LABEL.plist"
pkill -x DesktopToggle 2>/dev/null || true

mkdir -p "$HOME/Applications" "$HOME/Library/LaunchAgents"
rm -rf "$DEST"
cp -R build/DesktopToggle.app "$DEST"

sed "s|__APP_PATH__|$DEST|" "Resources/$LABEL.plist" > "$AGENT"
launchctl bootstrap "gui/$(id -u)" "$AGENT"

echo "Installed to $DEST and set to start at login."
echo "Click the eye icon in the menu bar or press Ctrl+Option+D."
