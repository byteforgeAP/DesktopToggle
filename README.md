# DesktopToggle

A tiny macOS menu bar app that hides and shows all your Desktop icons with one click.

![DesktopToggle demo](assets/demo.gif)

- **Click the eye icon** in the menu bar to hide your Desktop icons. Click again to bring them back.
- **Press `Ctrl + Option + D`** from anywhere to do the same.
- **Double-click the empty Desktop** while icons are hidden to bring them back.
- **Right-click the eye** for a menu with Quit. Quitting always brings your icons back.

Hiding and showing is instant with a [still wallpaper](#which-wallpapers-work-best). Your files aren't moved or deleted, only hidden, and they come back in the same arrangement.

Works on macOS 13 or later, on both Apple Silicon and Intel Macs. **Needs no permissions** — see [Permissions & privacy](#permissions--privacy).

## Download

1. Download `DesktopToggle-x.y.z.zip` from the [latest release](https://github.com/byteforgeAP/DesktopToggle/releases/latest).
2. Unzip it and move `DesktopToggle.app` to your Applications folder.
3. The app isn't notarized by Apple, so macOS blocks it the first time. Open it once, close the warning, then go to **System Settings → Privacy & Security**, scroll down and click **Open Anyway** next to DesktopToggle. You only need to do this once. If you'd rather not, build it from source below.

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

DesktopToggle has two ways to hide your icons, and picks the right one automatically.

### Instant mode (default)

When you hide your icons, DesktopToggle places an exact copy of your wallpaper over them: one borderless window per screen, sitting just below your app windows. To show the icons, it simply removes that window. Nothing on disk changes and Finder keeps running, so both directions are instant.

- The cover uses the same **Fill / Fit / Stretch / Center** setting as your real wallpaper, so it lines up exactly.
- It works across all **Spaces** and **multiple displays**, and rebuilds itself when you plug in or remove a screen.
- It **never takes focus**: single clicks on the hidden Desktop do nothing and your current app stays in front. A **double-click** brings the icons back.
- **Quitting** the app removes the cover, so your icons always come back.

### Slow mode (automatic fallback)

If the wallpaper can't be copied exactly (see the table below), DesktopToggle uses Finder's hidden `CreateDesktop` setting instead:

```bash
defaults write com.apple.finder CreateDesktop -bool false   # hide
defaults write com.apple.finder CreateDesktop -bool true    # show
killall Finder
```

This takes about a second because Finder has to restart, and Finder reopens any windows you had open. When slow mode is in use, **right-click the eye** to see why, plus a shortcut to the Wallpaper settings.

## Which wallpapers work best?

| Wallpaper | Mode | Why |
|---|---|---|
| Apple's still wallpapers (**iMac** colors, **Mac** colors, Radial Sky Blue) | ⚡ Instant | Single still image |
| **Solid Colors** | ⚡ Instant | Plain image |
| **Your own photos** (JPEG, PNG, HEIC) in **Pictures** | ⚡ Instant | Normal readable file, no prompt |
| Your own photos in **Desktop, Documents or Downloads** | ⚡ Instant | macOS asks once whether DesktopToggle may access that folder. Click **Allow**, or move the photo to Pictures to avoid the prompt |
| **Dynamic** wallpapers (e.g. Sonoma) that change with light/dark mode or time of day | 🐢 Slow | A single copy wouldn't always match |
| **Aerial** / animated video wallpapers | 🐢 Slow | Video can't be copied as a still image |
| Wallpapers set by **other apps** (Unsplash Wallpapers, etc.) | 🐢 Slow | macOS keeps them in that app's private folder and blocks other apps from reading them |
| **Shuffle** ("Change picture every…") | ⚡ Instant* | *If the picture changes while icons are hidden, the cover keeps showing the old one until you toggle again |

**Tip:** for the best experience, choose a still wallpaper in **System Settings → Wallpaper**, or save your own photo in **Pictures** and click **Add Photo**.

DesktopToggle never asks for extra access to read a protected wallpaper. It switches to slow mode instead.

## Permissions & privacy

**DesktopToggle asks for no permissions** in normal use.

| Permission | Needed? | Notes |
|---|---|---|
| Accessibility | ❌ No | The shortcut is registered with macOS's hotkey API (`RegisterEventHotKey`), so the app never sees any other keys you press |
| Screen Recording | ❌ No | It reads your wallpaper file; it never captures your screen |
| Full Disk Access | ❌ No | Protected wallpapers trigger slow mode instead |
| Files & Folders | Only in one case | If your wallpaper photo is in Desktop, Documents or Downloads, macOS asks once to let it read that folder. Only the wallpaper file is ever read. |
| Network | ❌ No | No networking code at all; nothing is collected or sent |

What it actually does:

- **Reads** your current wallpaper image (read-only)
- **Shows** a window with that image over your Desktop icons
- In slow mode only: **changes** Finder's `CreateDesktop` setting and **restarts** Finder (`/usr/bin/killall Finder`)
- `install.sh` adds a **login item** in `~/Library/LaunchAgents` so the app starts when you log in; `uninstall.sh` removes it

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
