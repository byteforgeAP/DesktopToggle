# DesktopToggle

A tiny macOS menu bar app that hides and shows all your Desktop icons with one click.

![DesktopToggle demo](assets/demo.gif)

- **Click the eye icon** in the menu bar to hide your Desktop icons. Click again to bring them back.
- **Press `Ctrl + Option + D`** from anywhere to do the same.
- **Right-click the eye** for a menu with Quit.

Your files aren't moved or deleted, only hidden, and they come back in the same arrangement.

## Requirements

- macOS 13 or later
- Xcode Command Line Tools, for `swiftc` (`xcode-select --install`)

## Install

```bash
git clone <this repo>
cd DesktopToggle
./install.sh
```

This builds the app, copies it to `~/Applications/DesktopToggle.app` and adds a login item, so it starts automatically every time you log in.

## Uninstall

```bash
./uninstall.sh
```

This removes the app and its login item, and makes your Desktop icons visible again.

## Build only

```bash
./build.sh
```

The app is written to `build/DesktopToggle.app`.

## How it works

macOS has a hidden Finder setting, `CreateDesktop`, that controls whether Desktop icons are drawn. DesktopToggle flips that setting and restarts Finder:

```bash
defaults write com.apple.finder CreateDesktop -bool false   # hide
defaults write com.apple.finder CreateDesktop -bool true    # show
killall Finder
```

The global shortcut uses Carbon's `RegisterEventHotKey`, so the app doesn't need Accessibility permission.

Each toggle takes about a second while Finder restarts, and any open Finder windows briefly close and reopen.

## Project layout

```
Sources/main.swift                         The whole app
Resources/Info.plist                       App bundle info (menu bar only, no Dock icon)
Resources/local.ayush.DesktopToggle.plist  Login item template
build.sh                                   Builds build/DesktopToggle.app
install.sh                                 Builds, installs and starts at login
uninstall.sh                               Removes everything and shows icons again
assets/demo.gif                            Demo shown above
```
