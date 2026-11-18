// DesktopToggle: hide/show all Desktop icons from the menu bar or with Ctrl+Option+D.
import Cocoa
import Carbon.HIToolbox

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var hotKeyRef: EventHotKeyRef?
    private var hotKeyRegistered = false

    private var iconsHidden: Bool {
        let v = CFPreferencesCopyAppValue("CreateDesktop" as CFString, "com.apple.finder" as CFString)
        return (v as? Bool) == false
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.target = self
        statusItem.button?.action = #selector(handleClick)
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        updateIcon()
        registerHotKey()
    }

    @objc private func handleClick() {
        // Right-click (or Ctrl-click) shows a small menu so the helper can be quit.
        if let e = NSApp.currentEvent, e.type == .rightMouseUp || e.modifierFlags.contains(.control) {
            let menu = NSMenu()
            menu.addItem(withTitle: iconsHidden ? "Show Desktop Icons" : "Hide Desktop Icons",
                         action: #selector(toggle), keyEquivalent: "").target = self
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
        setIconsHidden(!iconsHidden)
    }

    private func setIconsHidden(_ hide: Bool) {
        run("/usr/bin/defaults", ["write", "com.apple.finder", "CreateDesktop", "-bool", hide ? "false" : "true"])
        run("/usr/bin/killall", ["Finder"])
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self.updateIcon() }
    }

    // Once the app is gone there's no button left to bring the icons back, so show them on quit.
    @objc private func quit() {
        if iconsHidden { setIconsHidden(false) }
        NSApp.terminate(nil)
    }

    private func run(_ path: String, _ args: [String]) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        do { try p.run(); p.waitUntilExit() } catch { NSLog("DesktopToggle: failed to run \(path): \(error)") }
    }

    private func updateIcon() {
        let name = iconsHidden ? "eye.slash" : "eye"
        let image = NSImage(systemSymbolName: name, accessibilityDescription: "Toggle Desktop icons")
        image?.isTemplate = true
        statusItem.button?.image = image
        statusItem.button?.toolTip = iconsHidden ? "Desktop icons hidden — click to show (⌃⌥D)"
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
