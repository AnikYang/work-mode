# Contributing

Work Mode is a small native macOS app for keeping a Mac awake during AI work.
Keep contributions focused on reliable sleep prevention, keyboard behavior,
accessibility, and the native interface.

## Local development

Use an Apple Silicon Mac with macOS 14 or newer and the macOS 26+ SDK
(Xcode 26+ or matching Command Line Tools).

```sh
bash scripts/build.sh
bash scripts/test.sh
open "build/Work Mode.app"
```

The default tests register a temporary shortcut and briefly create power
assertions. They do not modify your keyboard mappings. Real built-in keyboard
mapping tests are opt-in:

```sh
WORKMODE_HARDWARE_TESTS=1 bash scripts/test.sh
```

These tests temporarily remap the built-in Focus key and then restore the
previous mappings. Run them in a local desktop session on a MacBook.

## Pull requests

- Describe the behavior before and after the change.
- Include relevant test results and a screenshot for visible changes.
- Verify both enabled and disabled states, custom shortcuts, and normal quit.
- Preserve unrelated keyboard mappings and restore keys on normal quit.
- Do not commit build outputs, local preferences, credentials, or desktop captures.

The app uses public Apple APIs and has no third-party runtime dependencies.
Changes that require additional permissions should explain why they are needed.
