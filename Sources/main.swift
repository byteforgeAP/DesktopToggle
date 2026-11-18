// DesktopToggle: hide/show all Desktop icons from the menu bar or with Ctrl+Option+D.
//
// Default method: cover the icons with a copy of the wallpaper, one window per screen,
// sitting just above the Desktop icons and below every app window. Instant both ways.
// Fallback (wallpaper can't be read, e.g. an animated wallpaper): Finder's hidden
// CreateDesktop setting plus a Finder restart, which takes about a second.
import Cocoa
import Carbon.HIToolbox

// Draws a wallpaper image the way the Desktop does (fill, fit, stretch or center).
final class WallpaperView: NSView {
    var image: NSImage?
    var scaling: NSImageScaling = .scaleProportionallyUpOrDown
    var allowClipping = true
    var fillColor: NSColor = .black
    var onDoubleClick: (() -> Void)?

    override func draw(_ dirtyRect: NSRect) {
        fillColor.setFill()
        bounds.fill()
        guard let image, image.size.width > 0, image.size.height > 0 else { return }

        let b = bounds, s = image.size
        var size: NSSize
        switch scaling {
        case .scaleAxesIndependently:
            size = b.size
        case .scaleNone:
            size = s
        default:
            let fill = max(b.width / s.width, b.height / s.height)
            let fit = min(b.width / s.width, b.height / s.height)
            let f = allowClipping ? fill : fit
            size = NSSize(width: s.width * f, height: s.height * f)
        }
        let rect = NSRect(x: b.midX - size.width / 2, y: b.midY - size.height / 2,
                          width: size.width, height: size.height)
        image.draw(in: rect, from: .zero, operation: .copy, fraction: 1)
    }

    // Swallow clicks so hidden icons can't be selected by accident; double-click shows them again.
    // The cover is removed only after the mouse is released, so no part of the double-click
    // reaches (and opens) an icon underneath.
    private var pendingDoubleClick = false

    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 { pendingDoubleClick = true }
    }

    override func mouseUp(with event: NSEvent) {
        guard pendingDoubleClick else { return }
        pendingDoubleClick = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in self?.onDoubleClick?() }
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

// A cover that never takes focus: clicking it must not activate DesktopToggle,
// or macOS would bring some other app's window to the front.
final class CoverPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var hotKeyRef: EventHotKeyRef?
    private var hotKeyRegistered = false
    private var isToggling = false // ignore clicks/shortcut presses while Finder restarts
    private let worker = DispatchQueue(label: "DesktopToggle.worker")
    private var covers: [NSPanel] = []
    private var imageCache: [URL: NSImage] = [:] // avoid re-decoding big wallpapers on every Space switch
    private var slowModeReason: String?            // set when the instant method had to fall back

    private static let finder = "com.apple.finder" as CFString
    private static let createDesktop = "CreateDesktop" as CFString

    private var finderHidesIcons: Bool {
        CFPreferencesAppSynchronize(Self.finder)
        let v = CFPreferencesCopyAppValue(Self.createDesktop, Self.finder)
        return (v as? Bool) == false
    }

    private var iconsHidden: Bool { !covers.isEmpty || finderHidesIcons }

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.target = self
        statusItem.button?.action = #selector(handleClick)
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        updateIcon()
        registerHotKey()

        // Keep the covers matching the real Desktop when screens or wallpapers change.
        NotificationCenter.default.addObserver(self, selector: #selector(refreshCovers),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(refreshCovers),
            name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
    }

    @objc private func handleClick() {
        // Right-click (or Ctrl-click) shows a small menu so the helper can be quit.
        if let e = NSApp.currentEvent, e.type == .rightMouseUp || e.modifierFlags.contains(.control) {
            let menu = NSMenu()
            menu.addItem(withTitle: iconsHidden ? "Show Desktop Icons" : "Hide Desktop Icons",
                         action: #selector(toggle), keyEquivalent: "").target = self
            if let reason = slowModeReason {
                menu.addItem(.separator())
                menu.addItem(withTitle: "Slow mode: \(reason)", action: nil, keyEquivalent: "")
                menu.addItem(withTitle: "Choose a Still Wallpaper for Instant Mode…",
                             action: #selector(openWallpaperSettings), keyEquivalent: "").target = self
            }
            menu.addItem(.separator())
            menu.addItem(withTitle: hotKeyRegistered ? "Shortcut: ⌃⌥D" : "Shortcut ⌃⌥D is used by another app",
                         action: nil, keyEquivalent: "")
            menu.addItem(withTitle: "Quit DesktopToggle", action: #selector(quit), keyEquivalent: "q").target = self
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else {
            toggle()
        }
    }

    @objc func toggle() {
        guard !isToggling else { return }

        if iconsHidden {
            removeCovers()
            if finderHidesIcons { setFinderHidesIcons(false) } else { updateIcon() }
        } else if showCovers() {
            updateIcon()
        } else {
            setFinderHidesIcons(true)
        }
    }

    // MARK: Wallpaper covers (instant)

    // Returns false if any screen's wallpaper can't be drawn, so the caller can fall back.
    private func showCovers() -> Bool {
        var windows: [NSPanel] = []
        for screen in NSScreen.screens {
            guard let view = wallpaperView(for: screen) else {
                windows.forEach { $0.orderOut(nil) }
                return false
            }
            let w = CoverPanel(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel],
                               backing: .buffered, defer: false)
            w.hidesOnDeactivate = false
            // Just below normal app windows. Anything at the Desktop's own levels counts as
            // "the wallpaper", and clicking it triggers macOS's click-wallpaper-to-reveal-desktop.
            w.level = NSWindow.Level(rawValue: NSWindow.Level.normal.rawValue - 1)
            w.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
            w.isReleasedWhenClosed = false
            w.hasShadow = false
            w.isOpaque = true
            w.contentView = view
            w.setFrame(screen.frame, display: true)
            w.orderFrontRegardless()
            windows.append(w)
        }
        covers = windows
        return !covers.isEmpty
    }

    private func removeCovers() {
        covers.forEach { $0.orderOut(nil) }
        covers = []
    }

    @objc private func refreshCovers() {
        guard !covers.isEmpty else { return }
        removeCovers()
        if !showCovers() { updateIcon() } // wallpaper became unreadable: icons are visible again
    }

    @objc private func openWallpaperSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Wallpaper-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }

    // Returns the wallpaper only when a still copy will look identical to the real Desktop.
    private func wallpaperImage(at url: URL) -> NSImage? {
        if let cached = imageCache[url] { return cached }

        if url.path.contains("/com.apple.wallpaper/aerials/") || url.pathExtension.lowercased() == "mov" {
            return fallBack("Aerial or video wallpapers can't be covered", url)
        }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            // Usually macOS privacy protection: the file lives inside another app's container.
            return fallBack("macOS blocked reading your wallpaper", url)
        }
        if CGImageSourceGetCount(source) > 1 {
            // Light/dark or time-of-day wallpaper: a single frame wouldn't always match.
            return fallBack("dynamic wallpapers can't be covered", url)
        }
        guard let image = NSImage(contentsOf: url), image.isValid else {
            return fallBack("macOS blocked reading your wallpaper", url)
        }
        slowModeReason = nil
        imageCache = [url: image] // keep only the current wallpaper in memory
        return image
    }

    private func fallBack(_ reason: String, _ url: URL) -> NSImage? {
        NSLog("DesktopToggle: \(reason) (\(url.path)); using the Finder method")
        slowModeReason = reason
        return nil
    }

    private func wallpaperView(for screen: NSScreen) -> WallpaperView? {
        let ws = NSWorkspace.shared
        guard let url = ws.desktopImageURL(for: screen), let image = wallpaperImage(at: url) else { return nil }
        let opts = ws.desktopImageOptions(for: screen) ?? [:]

        let view = WallpaperView(frame: NSRect(origin: .zero, size: screen.frame.size))
        view.image = image
        if let raw = opts[.imageScaling] as? NSNumber, let s = NSImageScaling(rawValue: raw.uintValue) {
            view.scaling = s
        }
        view.allowClipping = (opts[.allowClipping] as? Bool) ?? true
        view.fillColor = (opts[.fillColor] as? NSColor) ?? .black
        view.onDoubleClick = { [weak self] in self?.toggle() }
        return view
    }

    // MARK: Finder fallback (about a second)

    private func setFinderHidesIcons(_ hide: Bool) {
        isToggling = true
        updateIcon(hidden: hide) // feedback right away; the work happens off the main thread

        worker.async {
            self.applyFinderHidesIcons(hide)
            // Give Finder a moment to come back before accepting the next toggle.
            Thread.sleep(forTimeInterval: 0.4)
            DispatchQueue.main.async {
                self.isToggling = false
                self.updateIcon()
            }
        }
    }

    // Writes the Finder setting and restarts Finder. Blocking: call off the main thread (or on quit).
    private func applyFinderHidesIcons(_ hide: Bool) {
        CFPreferencesSetAppValue(Self.createDesktop, (!hide) as CFBoolean, Self.finder)
        CFPreferencesAppSynchronize(Self.finder)
        run("/usr/bin/killall", ["Finder"])
    }

    // Once the app is gone there's no button left to bring the icons back, so show them on quit.
    // (The covers disappear with the app; only the Finder setting needs undoing.)
    @objc private func quit() {
        worker.sync {} // let an in-progress toggle finish first
        removeCovers()
        if finderHidesIcons { applyFinderHidesIcons(false) }
        NSApp.terminate(nil)
    }

    private func run(_ path: String, _ args: [String]) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        do { try p.run(); p.waitUntilExit() } catch { NSLog("DesktopToggle: failed to run \(path): \(error)") }
    }

    private func updateIcon(hidden: Bool? = nil) {
        let hidden = hidden ?? iconsHidden
        let image = NSImage(systemSymbolName: hidden ? "eye.slash" : "eye",
                            accessibilityDescription: "Toggle Desktop icons")
        image?.isTemplate = true
        statusItem.button?.image = image
        statusItem.button?.toolTip = hidden ? "Desktop icons hidden — click to show (⌃⌥D)"
                                            : "Click to hide Desktop icons (⌃⌥D)"
    }

    private func registerHotKey() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, userData in
            let me = Unmanaged<AppDelegate>.fromOpaque(userData!).takeUnretainedValue()
            DispatchQueue.main.async { me.toggle() }
            return noErr
        }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), nil)

        let id = EventHotKeyID(signature: OSType(0x44544F47), id: 1) // 'DTOG'
        let status = RegisterEventHotKey(UInt32(kVK_ANSI_D), UInt32(controlKey | optionKey), id,
                                         GetApplicationEventTarget(), 0, &hotKeyRef)
        hotKeyRegistered = (status == noErr)
        if !hotKeyRegistered { NSLog("DesktopToggle: Ctrl+Option+D is already taken (status \(status))") }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory) // menu bar only, no Dock icon
app.run()
