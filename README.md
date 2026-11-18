# DesktopToggle

A tiny macOS menu bar app that hides and shows all your Desktop icons with one click.

![DesktopToggle demo](assets/demo.gif)

- **Click the eye icon** in the menu bar to hide your Desktop icons. Click again to bring them back.
- **Press `Ctrl + Option + D`** from anywhere to do the same.
- **Right-click the eye** for a menu with Quit. Quitting always brings your icons back.

Your files aren't moved or deleted, only hidden, and they come back in the same arrangement.

Works on macOS 13 or later, on both Apple Silicon and Intel Macs.

## Download

1. Download `DesktopToggle-x.y.z.zip` from the [latest release](https://github.com/byteforgeAP/DesktopToggle/releases/latest).
2. Unzip it and move `DesktopToggle.app` to your Applications folder.
3. The app isn't notarized by Apple, so macOS will block it the first time. Run this once, then open it:

   ```bash
   xattr -cr /Applications/DesktopToggle.app
   ```

To start it at login, add it in **System Settings → General → Login Items**.

## Install from source

Needs the Xcode Command Line Tools (`xcode-select --install`).

```bash
git clone https://github.com/byteforgeAP/DesktopToggle.git
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

The app is written to `build/DesktopToggle.app` as a universal binary. To make a release zip, run `./release.sh`.

## How it works

macOS has a hidden Finder setting, `CreateDesktop`, that controls whether Desktop icons are drawn. DesktopToggle flips that setting and restarts Finder:

```bash
defaults write com.apple.finder CreateDesktop -bool false   # hide
defaults write com.apple.finder CreateDesktop -bool true    # show
killall Finder
```

The global shortcut uses Carbon's `RegisterEventHotKey`, so the app doesn't need Accessibility permission.

Each toggle takes about a second while Finder restarts, and any open Finder windows briefly close and reopen.

If another app already uses `Ctrl + Option + D`, the shortcut won't work, but clicking the eye still does. The right-click menu tells you when this happens.

## License

[MIT](LICENSE) © 2026 Ayush Patel

## Project layout

```
Sources/main.swift                                   The whole app
Resources/Info.plist                                 App bundle info (menu bar only, no Dock icon)
Resources/io.github.byteforgeap.DesktopToggle.plist  Login item template
build.sh                                             Builds build/DesktopToggle.app (universal)
install.sh                                           Builds, installs and starts at login
uninstall.sh                                         Removes everything and shows icons again
release.sh                                           Builds a zip for GitHub Releases
assets/demo.gif                                      Demo shown above
LICENSE                                              MIT License
```
