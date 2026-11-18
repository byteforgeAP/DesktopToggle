// DesktopToggle: hide/show all Desktop icons from the menu bar or with Ctrl+Option+D.
import Cocoa
import Carbon.HIToolbox

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var hotKeyRef: EventHotKeyRef?

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
            menu.addItem(withTitle: "Shortcut: ⌃⌥D", action: nil, keyEquivalent: "")
            menu.addItem(withTitle: "Quit DesktopToggle", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else {
            toggle()
        }
    }

    @objc func toggle() {
        let hide = !iconsHidden
        let defaults = Process()
        defaults.launchPath = "/usr/bin/defaults"
        defaults.arguments = ["write", "com.apple.finder", "CreateDesktop", "-bool", hide ? "false" : "true"]
        defaults.launch(); defaults.waitUntilExit()

        let restart = Process()
        restart.launchPath = "/usr/bin/killall"
        restart.arguments = ["Finder"]
        restart.launch(); restart.waitUntilExit()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self.updateIcon() }
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
        RegisterEventHotKey(UInt32(kVK_ANSI_D), UInt32(controlKey | optionKey), id,
                            GetApplicationEventTarget(), 0, &hotKeyRef)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory) // menu bar only, no Dock icon
app.run()
