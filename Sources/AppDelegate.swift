import AppKit
import ApplicationServices
import SwiftUI
import ServiceManagement
import Sparkle

// MARK: - App Delegate

@MainActor
@Observable
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {

    private var statusItem: NSStatusItem?
    let engine = ScreenLockEngine()

    // @ObservationIgnored — @Observable's macro can't transform `lazy`.
    @ObservationIgnored let sparkleUserDriverDelegate = ScreenLockUserDriverDelegate()
    @ObservationIgnored lazy var sparkleUpdater = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: sparkleUserDriverDelegate
    )

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
        migrateLegacyPillColorKey()

        NSApp.setActivationPolicy(.accessory)

        createStatusItem()
        _ = sparkleUpdater  // forces lazy init so Sparkle starts at launch

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

        // Redraw the status icon when the display configuration changes — the
        // menu bar's effective thickness can shrink (e.g. moving from a notched
        // display to an external one) and leave the pre-rendered pill cropped.
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.updateIcon() }
        }

        // React to the user toggling menu-bar visibility in settings.
        NotificationCenter.default.addObserver(
            forName: JorvikStatusItemVisibility.didChangeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.applyStatusItemVisibility() }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        engine.stop()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        JorvikStatusItemVisibility.handleReopen()
        return true
    }

    // MARK: - Status item

    func createStatusItem() {
        guard JorvikStatusItemVisibility.isVisible else { return }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        // Persist the item's menu-bar slot across launches (and let a user ⌘-drag stick).
        statusItem?.autosaveName = "ScreenLockStatusItem"
        updateIcon()

        let menu = NSMenu()
        menu.delegate = self
        statusItem?.menu = menu
    }

    func applyStatusItemVisibility() {
        if JorvikStatusItemVisibility.isVisible {
            if statusItem == nil { createStatusItem() }
        } else if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
            statusItem = nil
        }
    }

    // One-shot removal of the user-chosen pill colour key from the old design.
    // The new pill uses fixed grey/light colours; the key is dead weight.
    private func migrateLegacyPillColorKey() {
        let migrated = "didMigratePillColorV2"
        if UserDefaults.standard.bool(forKey: migrated) { return }
        UserDefaults.standard.removeObject(forKey: "menuBarPillColor")
        UserDefaults.standard.set(true, forKey: migrated)
    }

    // MARK: - Icon

    func updateIcon() {
        let symbolName = engine.isActive ? "lock.display" : "display"
        statusItem?.button?.image = JorvikMenuBarPill.icon(
            symbolName: symbolName,
            accessibilityDescription: "ScreenLock"
        )
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

        actions.append(JorvikMenuBuilder.ActionItem(title: "-", action: #selector(noop), target: self))
        actions.append(JorvikMenuBuilder.ActionItem(
            title: "Check for Updates\u{2026}",
            action: #selector(checkForUpdates(_:)),
            target: self
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
    @objc func checkForUpdates(_ sender: Any?) {
        NSRunningApplication.current.activate(options: [.activateAllWindows])
        sparkleUpdater.checkForUpdates(sender)
    }

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
        JorvikSettingsView.showWindow(appName: "ScreenLock") {
            ScreenLockSettingsContent(delegate: delegate)
        }
    }
}

/// Keeps Sparkle's update UI visible across the whole session, including
/// when the user switches to another app mid-download. See KB:
/// `conventions/sparkle-integration.md` §6 for the rationale.
final class ScreenLockUserDriverDelegate: NSObject, SPUStandardUserDriverDelegate {
    private var sessionObserver: NSObjectProtocol?
    private var elevatedWindows: [(window: NSWindow, originalLevel: NSWindow.Level)] = []

    func standardUserDriverWillShowModalAlert() {
        bringForward()
    }

    func standardUserDriverWillHandleShowingUpdate(_ handleShowingUpdate: Bool, forUpdate update: SUAppcastItem, state: SPUUserUpdateState) {
        startFocusGuard()
        bringForward()
    }

    func standardUserDriverWillFinishUpdateSession() {
        stopFocusGuard()
    }

    private func bringForward() {
        NSRunningApplication.current.activate(options: [.activateAllWindows])
        elevateAllWindows()
    }

    private func startFocusGuard() {
        guard sessionObserver == nil else { return }
        sessionObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.bringForward()
        }
    }

    private func stopFocusGuard() {
        if let obs = sessionObserver {
            NotificationCenter.default.removeObserver(obs)
            sessionObserver = nil
        }
        for entry in elevatedWindows {
            entry.window.level = entry.originalLevel
        }
        elevatedWindows.removeAll()
    }

    private func elevateAllWindows() {
        for window in NSApp.windows where window.isVisible && window.level == .normal {
            elevatedWindows.append((window, window.level))
            window.level = .floating
        }
    }
}
