#!/bin/bash
# Stops the app, removes it and its login item, and makes Desktop icons visible again.
set -euo pipefail

LABEL="local.ayush.DesktopToggle"

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
pkill -x DesktopToggle 2>/dev/null || true
rm -f "$HOME/Library/LaunchAgents/$LABEL.plist"
rm -rf "$HOME/Applications/DesktopToggle.app"

# Don't leave the icons hidden.
defaults delete com.apple.finder CreateDesktop 2>/dev/null || true
killall Finder 2>/dev/null || true

echo "DesktopToggle removed. Desktop icons are visible."
