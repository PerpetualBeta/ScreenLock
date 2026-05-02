import SwiftUI

struct ScreenLockSettingsContent: View {
    let delegate: AppDelegate

    var body: some View {
        Section("Shortcut") {
            JorvikShortcutRecorder(
                label: "Lock Screen",
                keyCode: Binding(
                    get: { delegate.hotkeyCode },
                    set: { delegate.hotkeyCode = $0 }
                ),
                modifiers: Binding(
                    get: { delegate.hotkeyModifiers },
                    set: { delegate.hotkeyModifiers = $0 }
                ),
                displayString: { delegate.shortcutDisplayString() },
                onChanged: nil,
                eventTapToDisable: nil
            )
        }

        Section("Permissions") {
            HStack {
                Text("Accessibility")
                Spacer()
                if AXIsProcessTrusted() {
                    Label("Granted", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                } else {
                    Button("Grant Access") {
                        let opts = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
                        AXIsProcessTrustedWithOptions(opts)
                    }
                    .font(.caption)
                }
            }
        }

        MenuBarPillSettings { delegate.updateIcon() }
    }
}
