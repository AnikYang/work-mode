import AppKit
import Carbon
import IOKit.pwr_mgt
import IOKit.hid
import IOKit.hidsystem

func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else { fatalError("FAIL: \(message)") }
    print("PASS: \(message)")
}

let suiteName = "local.anik.WorkMode.tests.\(UUID().uuidString)"
let defaults = UserDefaults(suiteName: suiteName)!
defer { defaults.removePersistentDomain(forName: suiteName) }

check(Shortcut.defaultShortcut.displayName == "F6", "Default shortcut is F6")
check(Shortcut.load(from: defaults) == .defaultShortcut, "Missing preference falls back to F6")
check(!Shortcut(keyCode: 0, modifiers: 0).isValid, "Bare A cannot hijack typing")
check(!Shortcut(keyCode: 0, modifiers: UInt32(shiftKey)).isValid, "Shift+A cannot hijack typing")
check(!Shortcut(keyCode: 400, modifiers: UInt32(cmdKey)).isValid, "Unknown key is rejected")
check(!Shortcut(keyCode: UInt32(kVK_F6), modifiers: 0x80000000).isValid, "Corrupt modifiers are rejected")
let custom = Shortcut(keyCode: 0, modifiers: UInt32(controlKey | optionKey | cmdKey))
check(custom.isValid && custom.displayName == "⌃⌥⌘A", "Custom shortcut validates and displays")
custom.save(to: defaults)
check(Shortcut.load(from: defaults) == custom, "Custom shortcut survives preference round trip")
defaults.set(Data("invalid-json".utf8), forKey: Shortcut.storageKey)
check(Shortcut.load(from: defaults) == .defaultShortcut, "Corrupt preference falls back safely")

let app = NSApplication.shared
check(AccentColor.load(from: defaults) == .defaultColor, "Missing color preference uses amber")
let customColor = AccentColor(hex: "  #12aBeF\n")!
check(customColor.hex == "#12ABEF", "Custom color accepts and normalizes a six-digit hex value")
for value in ["", "#FFF", "#12345678", "GG1234", "##123456", "１２３４５６"] {
    check(AccentColor(hex: value) == nil, "Reject invalid color: \(value)")
}
customColor.save(to: defaults)
check(AccentColor.load(from: defaults) == customColor, "Custom color survives preference round trip")
defaults.set("invalid", forKey: AccentColor.storageKey)
check(AccentColor.load(from: defaults) == .defaultColor, "Corrupt color preference falls back safely")

func opaquePixelColors(_ image: NSImage) -> [NSColor] {
    let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
    return (0..<bitmap.pixelsHigh).flatMap { y in
        (0..<bitmap.pixelsWide).compactMap { x -> NSColor? in
            guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB), color.alphaComponent > 0.9 else { return nil }
            return color
        }
    }
}
let redIcon = StatusIcon.make(enabled: true, color: AccentColor(hex: "FF0000")!)
let redPixels = opaquePixelColors(redIcon)
check(!redIcon.isTemplate && !redPixels.isEmpty && redPixels.allSatisfy {
    // AppKit's TIFF snapshot may convert through the calibrated RGB space.
    $0.redComponent > 0.9 && $0.greenComponent < 0.2 && $0.blueComponent < 0.2
}, "Enabled status icon actually renders in the selected color")
let grayPixels = opaquePixelColors(StatusIcon.make(enabled: false, color: customColor))
check(!grayPixels.isEmpty && grayPixels.allSatisfy {
    abs($0.redComponent - $0.greenComponent) < 0.01 && abs($0.greenComponent - $0.blueComponent) < 0.01
        && $0.redComponent > 0.4 && $0.redComponent < 0.7
}, "Disabled status icon stays gray regardless of the selected color")

let hotKey = HotKeyManager()
let testKey = Shortcut(keyCode: UInt32(kVK_F19), modifiers: UInt32(controlKey | optionKey | cmdKey))
try hotKey.register(testKey)
let conflicting = HotKeyManager()
do {
    try conflicting.register(testKey)
    fatalError("FAIL: Duplicate shortcut must report a conflict")
} catch {
    print("PASS: An occupied shortcut reports a conflict")
}
hotKey.unregister()
try hotKey.register(testKey)
hotKey.unregister()
print("PASS: Real global hotkey registers, releases and re-registers")

// Exercise the Carbon callback in this test process, including held-key repeats.
// This is deliberately not a simulation of a physical, system-wide key press.
try hotKey.register(testKey)
var activationCount = 0
hotKey.onPress = { activationCount += 1 }
func deliverHotKeyEvent(_ kind: UInt32, id: UInt32 = 1) {
    var event: EventRef?
    check(CreateEvent(nil, OSType(kEventClassKeyboard), kind, GetCurrentEventTime(),
                      EventAttributes(kEventAttributeUserEvent), &event) == noErr, "Create callback test event")
    guard let event else { fatalError("Missing event") }
    defer { ReleaseEvent(event) }
    var identifier = EventHotKeyID(signature: 0x574D4F44, id: id)
    check(SetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                            MemoryLayout<EventHotKeyID>.size, &identifier) == noErr, "Set callback test identifier")
    _ = SendEventToEventTarget(event, GetEventDispatcherTarget())
}
deliverHotKeyEvent(UInt32(kEventHotKeyPressed), id: 99)
check(activationCount == 0, "Unrelated hotkeys are ignored")
deliverHotKeyEvent(UInt32(kEventHotKeyPressed))
deliverHotKeyEvent(UInt32(kEventHotKeyPressed))
check(activationCount == 1, "Holding a key only toggles once")
deliverHotKeyEvent(UInt32(kEventHotKeyReleased))
deliverHotKeyEvent(UInt32(kEventHotKeyPressed))
check(activationCount == 2, "Releasing and pressing again toggles again")
func deliverAppKeyEvent(_ type: NSEvent.EventType, repeating: Bool = false,
                        modifiers: NSEvent.ModifierFlags = [.control, .option, .command]) {
    let event = NSEvent.keyEvent(with: type, location: .zero,
                                modifierFlags: modifiers,
                                timestamp: ProcessInfo.processInfo.systemUptime,
                                windowNumber: 0, context: nil,
                                characters: "", charactersIgnoringModifiers: "",
                                isARepeat: repeating, keyCode: UInt16(testKey.keyCode))!
    app.sendEvent(event)
}
deliverAppKeyEvent(.keyUp)
deliverAppKeyEvent(.keyDown)
check(activationCount == 3, "App-directed key events also toggle")
deliverAppKeyEvent(.keyDown, repeating: true)
deliverHotKeyEvent(UInt32(kEventHotKeyPressed))
check(activationCount == 3, "Local repeat and Carbon duplicate do not double-toggle")
deliverAppKeyEvent(.keyUp)
deliverAppKeyEvent(.keyDown)
check(activationCount == 4, "Start a shortcut before releasing modifiers first")
deliverAppKeyEvent(.keyUp, modifiers: [])
deliverAppKeyEvent(.keyDown)
check(activationCount == 5, "Releasing modifiers before the key does not leave the shortcut stuck")
deliverAppKeyEvent(.keyUp)
hotKey.unregister()

func ownedWorkAssertions() -> [NSDictionary] {
    var unmanaged: Unmanaged<CFDictionary>?
    check(IOPMCopyAssertionsByProcess(&unmanaged) == kIOReturnSuccess, "Read system power assertions")
    guard let dictionary = unmanaged?.takeRetainedValue() as? [NSNumber: [NSDictionary]] else { return [] }
    return (dictionary[NSNumber(value: ProcessInfo.processInfo.processIdentifier)] ?? []).filter {
        ($0[kIOPMAssertionNameKey] as? String)?.hasPrefix("Work Mode") == true
    }
}

let power = PowerManager()
try power.enable()
try power.enable()
check(power.isEnabled, "Enable is idempotent")
let assertions = ownedWorkAssertions()
check(assertions.count == 2, "Exactly two real power assertions exist")
let types = Set(assertions.compactMap { $0[kIOPMAssertionTypeKey] as? String })
check(types.contains(kIOPMAssertionTypePreventUserIdleSystemSleep), "System idle sleep is prevented")
check(types.contains(kIOPMAssertionTypePreventUserIdleDisplaySleep), "Display idle sleep is prevented")
power.disable()
power.disable()
check(!power.isEnabled && ownedWorkAssertions().isEmpty, "Disable releases all assertions and is idempotent")
do {
    let temporary = PowerManager()
    try temporary.enable()
}
check(ownedWorkAssertions().isEmpty, "Object cleanup releases assertions")

typealias Remapper = FocusKeyRemapper
let unrelated: [String: Any] = [Remapper.sourceKey: NSNumber(value: UInt64(0x700000039)),
                                 Remapper.destinationKey: NSNumber(value: UInt64(0x700000029))]
let originalFocus: [String: Any] = [Remapper.sourceKey: NSNumber(value: Remapper.focusUsage),
                                    Remapper.destinationKey: NSNumber(value: UInt64(0x700000040))]
let mapped = Remapper.replacingFocus(in: [unrelated, originalFocus])
check(mapped.count == 2 && mapped.contains(where: Remapper.isOwnedMapping), "Replace only the Focus hardware usage")
check(NSDictionary(dictionary: mapped[0]).isEqual(to: unrelated), "Keep unrelated user mappings")
let restored = Remapper.restoringFocus(in: mapped, original: [originalFocus])
check(NSArray(array: restored).isEqual(to: [unrelated, originalFocus]), "Restore the prior Focus mapping")
let changedElsewhere = [unrelated, originalFocus]
check(NSArray(array: Remapper.restoringFocus(in: changedElsewhere, original: [])).isEqual(to: changedElsewhere),
      "Do not overwrite a later mapping installed by another tool")

if ProcessInfo.processInfo.environment["WORKMODE_HARDWARE_TESTS"] == "1" {
    // Opt-in real device round-trip, scoped to the built-in keyboard.
    let hidClient = IOHIDEventSystemClientCreateSimpleClient(nil)
    let keyboards = (IOHIDEventSystemClientCopyServices(hidClient) as? [IOHIDServiceClient] ?? []).filter {
        IOHIDServiceClientConformsTo($0, UInt32(kHIDPage_GenericDesktop), UInt32(kHIDUsage_GD_Keyboard)) != 0
            && (IOHIDServiceClientCopyProperty($0, "Built-In" as CFString) as? NSNumber)?.boolValue == true
    }
    func readMapping(_ service: IOHIDServiceClient) -> [[String: Any]] {
        IOHIDServiceClientCopyProperty(service, Remapper.property as CFString) as? [[String: Any]] ?? []
    }
    check(!keyboards.isEmpty, "Find this Mac's built-in keyboard")
    let beforeMappings = keyboards.map(readMapping)
    do {
        let remapper = Remapper(defaults: defaults)
        defer { remapper.restore() }
        try remapper.activate()
        try remapper.activate()
        let active = remapper.isActive
        let mappingApplied = keyboards.allSatisfy { readMapping($0).contains(where: Remapper.isOwnedMapping) }
        // Simulate a subsequent launch recovering a saved mapping after abnormal exit.
        let recovery = Remapper(defaults: defaults)
        recovery.restore()
        remapper.restore()
        // Check only after restoring, so a test assertion cannot leave a remap behind.
        check(active, "Built-in moon key takeover is idempotent")
        check(mappingApplied, "macOS confirms the actual moon-key-to-F6 mapping")
        for (index, keyboard) in keyboards.enumerated() {
            check(NSArray(array: readMapping(keyboard)).isEqual(to: beforeMappings[index]),
                  "Restore the exact prior built-in keyboard mappings")
        }
        check(defaults.object(forKey: Remapper.backupKey) == nil, "Clear recovery backup after successful restore")
    }
} else {
    print("SKIP: Hardware remap tests (opt in with WORKMODE_HARDWARE_TESTS=1)")
}
print("All core checks passed.")
