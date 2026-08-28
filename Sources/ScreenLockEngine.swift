import AppKit
import ApplicationServices

// MARK: - Module-level state for C-compatible CGEvent tap callback

private var _hotkeyCode: UInt16 = 7  // X key
private var _hotkeyModifiers: NSEvent.ModifierFlags = [.command, .control, .option, .shift]  // Hyper
private var _screenLockTap: CFMachPort?
private var _onTriggered: (() -> Void)?

// MARK: - CGEvent tap callback

private func screenLockCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    // Auto-re-enable if macOS disabled the tap
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let tap = _screenLockTap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
        return Unmanaged.passUnretained(event)
    }

    guard type == .keyDown else {
        return Unmanaged.passUnretained(event)
    }

    let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
    let flags = NSEvent.ModifierFlags(rawValue: UInt(event.flags.rawValue))
        .intersection(.deviceIndependentFlagsMask)

    // Check if the pressed key matches our hotkey (use contains, not ==,
    // because HyperCaps unions modifiers onto existing flags)
    let requiredFlags = _hotkeyModifiers.intersection(.deviceIndependentFlagsMask)
    if keyCode == _hotkeyCode && flags.contains(requiredFlags) {
        DispatchQueue.main.async { _onTriggered?() }
        return nil // consume the event
    }

    return Unmanaged.passUnretained(event)
}

// MARK: - ScreenLockEngine

@MainActor
@Observable
final class ScreenLockEngine {
    var isActive: Bool = false
    var permissionGranted: Bool = false
    var triggerCount: Int = 0

    private var eventTap: CFMachPort?
    private var permissionTimer: Timer?

    // MARK: - Public API

    func start(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) {
        guard !isActive else { return }

        _hotkeyCode = keyCode
        _hotkeyModifiers = modifiers
        _onTriggered = { [weak self] in
            Task { @MainActor in
                self?.activateScreenSaver()
            }
        }

        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        permissionGranted = trusted

        if trusted {
            if tryCreateEventTap() {
                isActive = true
            }
        } else {
            permissionTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] timer in
                if AXIsProcessTrusted() {
                    Task { @MainActor in
                        guard let self else { return }
                        self.permissionGranted = true
                        if self.tryCreateEventTap() {
                            self.isActive = true
                        }
                    }
                    timer.invalidate()
                }
            }
        }
    }

    func stop() {
        isActive = false
        permissionTimer?.invalidate()
        permissionTimer = nil
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        eventTap = nil
        _screenLockTap = nil
    }

    func updateHotkey(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) {
        _hotkeyCode = keyCode
        _hotkeyModifiers = modifiers
    }

    // MARK: - Screen saver activation

    private func activateScreenSaver() {
        triggerCount += 1
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            process.arguments = ["-a", "ScreenSaverEngine"]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            try? process.run()
        }
    }

    // MARK: - CGEvent tap

    private func tryCreateEventTap() -> Bool {
        if eventTap != nil { return true }

        let mask: CGEventMask = (1 << CGEventType.keyDown.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .tailAppendEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: screenLockCallback,
            userInfo: nil
        ) else {
            return false
        }

        eventTap = tap
        _screenLockTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }
}
