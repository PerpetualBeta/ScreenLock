import AppKit
import ApplicationServices
import SwiftUI
import ServiceManagement

// MARK: - App Delegate

@MainActor
@Observable
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {

    private var statusItem: NSStatusItem!
    let engine = ScreenLockEngine()
    let updateChecker = JorvikUpdateChecker(repoName: "ScreenLock")

    // Settings (stored properties for @Observable, synced to UserDefaults)
    var hotkeyCode: UInt16 = {
        let val = UserDefaults.standard.object(forKey: "hotkeyCode")
        return val != nil ? UInt16(UserDefaults.standard.integer(forKey: "hotkeyCode")) : 7  // X
    }() {
        didSet {
            UserDefaults.standard.set(Int(hotkeyCode), forKey: "hotkeyCode")
            engine.updateHotkey(keyCode: hotkeyCode, modifiers: hotkeyModifiers)
            republishHotkey()
        }
    }

    var hotkeyModifiers: NSEvent.ModifierFlags = {
        let val = UserDefaults.standard.object(forKey: "hotkeyModifiers")
        if let raw = val as? UInt {
            return NSEvent.ModifierFlags(rawValue: raw)
        }
        return [.command, .control, .option, .shift]  // Hyper
    }() {
        didSet {
            UserDefaults.standard.set(hotkeyModifiers.rawValue, forKey: "hotkeyModifiers")
            engine.updateHotkey(keyCode: hotkeyCode, modifiers: hotkeyModifiers)
            republishHotkey()
        }
    }

    /// Push current binding to the JorvikKit registry so ShortcutHUD can list it.
    private func republishHotkey() {
        JorvikHotkeyRegistry.publish([
            JorvikHotkey(actionTitle: "Lock Screen Now",
                         keyCode: hotkeyCode,
                         modifiers: hotkeyModifiers,
                         activeContext: .anywhere),
        ])
    }

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateIcon()
        JorvikMenuBarPill.apply(to: statusItem.button!)
        updateChecker.checkOnSchedule()

        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        DistributedNotificationCenter.default.addObserver(
            self,
            selector: #selector(appearanceChanged),
            name: NSNotification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil
        )

        // Start the engine
        engine.start(keyCode: hotkeyCode, modifiers: hotkeyModifiers)
        republishHotkey()

        // Poll for isActive to update icon once permission is granted
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] timer in
            Task { @MainActor in
                guard let self else { timer.invalidate(); return }
                self.updateIcon()
                if self.engine.isActive { timer.invalidate() }
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        engine.stop()
    }

    @objc private func appearanceChanged() {
        if let button = statusItem.button {
            JorvikMenuBarPill.refresh(on: button)
        }
    }

    // MARK: - Icon

    private func updateIcon() {
        let symbolName = engine.isActive ? "lock.display" : "display"
        if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "ScreenLock") {
            image.isTemplate = true
            statusItem.button?.image = image
        } else {
            statusItem.button?.title = "🔒"
        }
    }

    // MARK: - Dynamic menu (NSMenuDelegate)

    func menuNeedsUpdate(_ menu: NSMenu) {
        updateIcon()

        var actions: [JorvikMenuBuilder.ActionItem] = []

        // Lock now
        actions.append(JorvikMenuBuilder.ActionItem(
            title: "Lock Screen Now",
            action: #selector(lockNow),
            target: self,
            keyEquivalent: ""
        ))

        actions.append(JorvikMenuBuilder.ActionItem(title: "-", action: #selector(noop), target: self))

        // Status
        let shortcutStr = "Shortcut: \(shortcutDisplayString())"
        let shortcutAttr = NSAttributedString(string: shortcutStr, attributes: [
            .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
            .foregroundColor: NSColor.secondaryLabelColor
        ])
        actions.append(JorvikMenuBuilder.ActionItem(
            title: shortcutStr,
            action: #selector(noop),
            target: self,
            isEnabled: false,
            attributedTitle: shortcutAttr
        ))

        let countStr = "Times locked: \(engine.triggerCount)"
        let countAttr = NSAttributedString(string: countStr, attributes: [
            .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
            .foregroundColor: NSColor.secondaryLabelColor
        ])
        actions.append(JorvikMenuBuilder.ActionItem(
            title: countStr,
            action: #selector(noop),
            target: self,
            isEnabled: false,
            attributedTitle: countAttr
        ))

        let built = JorvikMenuBuilder.buildMenu(
            appName: "ScreenLock",
            aboutAction: #selector(openAbout),
            settingsAction: #selector(openSettings),
            target: self,
            actions: actions
        )

        menu.removeAllItems()
        for item in built.items {
            built.removeItem(item)
            menu.addItem(item)
        }
    }

    // MARK: - Actions

    @objc private func lockNow() {
        engine.triggerCount += 1
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            process.arguments = ["-a", "ScreenSaverEngine"]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            try? process.run()
        }
    }

    @objc private func noop() {}

    // MARK: - Shortcut display

    func shortcutDisplayString() -> String {
        JorvikShortcutPanel.displayString(keyCode: hotkeyCode, modifiers: hotkeyModifiers)
    }

    // MARK: - About & Settings

    @objc private func openAbout() {
        JorvikAboutView.showWindow(
            appName: "ScreenLock",
            repoName: "ScreenLock",
            productPage: "utilities/screenlock"
        )
    }

    @objc private func openSettings() {
        let delegate = self
        JorvikSettingsView.showWindow(
            appName: "ScreenLock",
            updateChecker: updateChecker
        ) {
            ScreenLockSettingsContent(delegate: delegate)
        }
    }
}
