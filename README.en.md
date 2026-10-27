<p align="center"><img src="docs/assets/app-icon.png" width="100" alt="Work Mode sun icon"></p>

<h1 align="center">Work Mode</h1>
<p align="center">Keep your Mac awake while AI works.</p>
<p align="center">Native Swift · Apple Silicon · macOS 14+ · MIT</p>
<p align="center"><a href="README.md">简体中文</a> · English</p>

Work Mode is a lightweight macOS menu bar app for long AI tasks. Press **F6** before running a model, generating content, or starting an agent workflow. Your Mac and display stay awake until you toggle Work Mode off.

It repurposes the MacBook's **F6 Do Not Disturb key** as a keep-awake switch. Press the key with the moon symbol directly—no Fn required.

<p align="center"><img src="docs/assets/work-mode-hud.png" width="420" alt="Work Mode's native sun notification capsule"></p>

## Features

- Prevent idle system sleep and idle display sleep during long AI tasks.
- Take over the built-in Focus key while the default F6 shortcut is selected; restore it when changing shortcuts or quitting normally.
- Record a global shortcut: F1–F20, or a combination with Command, Option, or Control.
- Show a native sun capsule at the top of the display, with Liquid Glass on macOS 26+ and system material on older versions.
- No third-party runtime dependencies, polling, simulated mouse movement, or persistent child processes.
- No account, network connection, telemetry, Accessibility permission, or Input Monitoring permission required.

You enable Work Mode manually; it does not detect AI activity. It replaces the **key's purpose**, not the notification system: it does not silence notifications or change your current Focus state.

## Install and use

Check [Releases](https://github.com/AnikYang/work-mode/releases) for Apple Silicon builds, or build from source below. Distributed builds are ad-hoc signed and are not yet Developer ID signed or notarized. The interface is currently in Simplified Chinese.

1. Open `Work Mode.app`. It starts disabled.
2. Press the built-in **F6 moon key** to enable Work Mode.
3. Press it again to disable. A filled sun means enabled; an outlined sun means disabled.
4. Click the shortcut control in settings to record another shortcut. Escape cancels; “恢复 F6” restores the default.
5. Closing settings leaves the app in the menu bar. Quitting normally releases the sleep assertions and restores the Focus key.

## Build and test

Use an Apple Silicon Mac running macOS 14+, with the **macOS 26+ SDK** from Xcode 26+ or matching Command Line Tools.

```sh
git clone https://github.com/AnikYang/work-mode.git
cd work-mode
bash scripts/build.sh
bash scripts/test.sh
open "build/Work Mode.app"
bash scripts/package.sh
```

No third-party packages are needed. Packaging creates a versioned ZIP and prints its SHA-256 checksum.

Core tests cover shortcut persistence, registration and conflicts, duplicate events, real power assertions, and mapping restoration logic. They briefly register a test shortcut and power assertions, but do not change real keyboard mappings.

Opt into the real built-in keyboard mapping test on a MacBook desktop session:

```sh
WORKMODE_HARDWARE_TESTS=1 bash scripts/test.sh
```

This temporarily remaps the Focus key and restores the original mappings. Also verify physically that pressing F6 in another app toggles Work Mode without changing Do Not Disturb.

## Scope

- Prevents **automatic idle sleep**. Lid closure, manual sleep, shutdown, and low-battery protection remain controlled by macOS.
- Does not change screen savers, locking policies, connectivity, or AI service limits.
- Focus-key takeover targets the built-in keyboard. External keyboards can use standard F6 or another shortcut.
- After a forced termination, reopen the app and quit normally to restore the mapping. Rebooting also clears temporary mappings.
- Turn Work Mode off when your long-running task finishes.

## Implementation and contributing

SwiftUI and AppKit provide the UI. Carbon handles global shortcuts. IOKit holds `PreventUserIdleSystemSleep` and `PreventUserIdleDisplaySleep` assertions. The keyboard remap uses Apple's [TN2450](https://developer.apple.com/library/archive/technotes/tn2450/) API and preserves existing mappings.

See [CONTRIBUTING.md](CONTRIBUTING.md). Licensed under the [MIT License](LICENSE).
