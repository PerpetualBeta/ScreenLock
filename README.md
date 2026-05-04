# ScreenLock

A macOS utility that starts your screen saver with a global keyboard shortcut. One keypress to lock your Mac when you walk away.

## Requirements

- macOS 14 (Sonoma) or later

## Installation

Two formats on every release — both signed and notarised, pick whichever suits:

- **[Installer (`.pkg`)](https://github.com/PerpetualBeta/ScreenLock/releases/latest/download/ScreenLock.pkg)** — recommended for first-time installs. Double-click to run; macOS Installer places the app in `/Applications` without quarantine or App Translocation.
- **[Download (`.zip`)](https://github.com/PerpetualBeta/ScreenLock/releases/latest)** — unzip and drag `ScreenLock.app` to your Applications folder.

After installation:

1. Launch ScreenLock — a display icon appears in your menu bar
2. Grant Accessibility permission when prompted

## How It Works

ScreenLock listens for a configurable global hotkey and instantly launches the macOS screen saver when triggered. If your Mac is set to require a password after the screen saver starts, this effectively locks your machine in one keypress.

The default shortcut is **Hyper+X** (⌘⌃⌥⇧X) — designed to work with [HyperCaps](https://github.com/PerpetualBeta/HyperCaps), which turns Caps Lock into a Hyper Key. Press Caps Lock + X to lock your screen.

Any shortcut with at least one modifier key can be configured in Settings.

## Menu Bar

The display icon in the menu bar provides:

- **Lock Screen Now** — start the screen saver immediately (also works via mouse)
- **Shortcut** — shows the current keyboard shortcut
- **Times locked** — running count of how many times you've locked the screen
- **Settings** — configure the shortcut and permissions
- **About** — version info and update check

## Settings

### Shortcut

Click **Change…** to record a new keyboard shortcut. The shortcut must include at least one modifier key (⌘, ⌃, ⌥, or ⇧). The default is ⌘⌃⌥⇧X (Hyper+X).

### General

- **Accessibility** — permission status and grant button
- **Menu bar icon pill** — optional grey background for stronger contrast on busy or wallpaper-tinted menu bars (off by default)
- **Launch at Login** — start automatically when you log in

Auto-updates are handled by Sparkle. Use the **Check for Updates…** entry in the menu to check on demand; Sparkle's prompt offers an "Automatically download and install updates in the future" checkbox the first time an update is available.

## Permissions

### Accessibility (required)

Needed to listen for the global keyboard shortcut.

- Prompted automatically on first launch
- Grant in: **System Settings → Privacy & Security → Accessibility**
- Without this, the keyboard shortcut will not work

## Locking Your Mac

For ScreenLock to actually lock your Mac (not just show the screen saver), enable:

**System Settings → Lock Screen → Require password after screen saver begins or display is turned off → Immediately**

With this set, starting the screen saver via ScreenLock will require your password to return.

## Using with HyperCaps

ScreenLock pairs naturally with [HyperCaps](https://github.com/PerpetualBeta/HyperCaps). With both running:

1. **Caps Lock + X** locks your screen
2. **Shift + Caps Lock** toggles Caps Lock on/off
3. **Caps Lock + any key** sends a Hyper Key shortcut

The default Hyper+X shortcut works out of the box with HyperCaps. No configuration needed.

## Building from Source

ScreenLock uses Swift Package Manager. No Xcode project is required.

```bash
cd ~/Desktop/"Jorvik Software"/ScreenLock
./build.sh
open _BuildOutput/ScreenLock.app
```

The build script runs `swift build -c release`, then assembles the `.app` bundle in `_BuildOutput/` with the executable, icon, and Info.plist.

## How It Works (Technical)

ScreenLock installs a CGEvent tap at the **tail** of the keyboard event pipeline using `tailAppendEventTap`. This is important — it ensures the tap sees events *after* other keyboard utilities (like HyperCaps) have finished injecting modifier flags.

When the configured hotkey is detected, the screen saver is launched via `open -a ScreenSaverEngine`.

## Troubleshooting

### The shortcut doesn't work

Make sure ScreenLock has **Accessibility** permission in System Settings → Privacy & Security → Accessibility. You may need to remove and re-add it if you've rebuilt the app.

### The screen saver starts but doesn't lock

Enable **System Settings → Lock Screen → Require password after screen saver begins → Immediately**.

### Using with HyperCaps and the shortcut isn't detected

ScreenLock must see events after HyperCaps has processed them. This is handled automatically — ScreenLock uses a tail-append event tap. If you're having issues, ensure both apps have Accessibility permission.

---

ScreenLock is provided by [Jorvik Software](https://jorviksoftware.cc/). If you find it useful, consider [buying me a coffee](https://jorviksoftware.cc/donate).
