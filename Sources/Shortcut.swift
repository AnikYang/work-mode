import AppKit
import Carbon

struct Shortcut: Codable, Equatable {
    let keyCode: UInt32
    let modifiers: UInt32

    static let defaultShortcut = Shortcut(keyCode: UInt32(kVK_F6), modifiers: 0)
    static let storageKey = "globalShortcut.v1"
    static let allowedModifiers = UInt32(cmdKey | optionKey | controlKey | shiftKey)

    static let keyNames: [UInt32: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
        8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y",
        17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5", 24: "=",
        25: "9", 26: "7", 27: "−", 28: "8", 29: "0", 30: "]", 31: "O", 32: "U",
        33: "[", 34: "I", 35: "P", 36: "↩", 37: "L", 38: "J", 39: "'", 40: "K",
        41: ";", 42: "\\", 43: ",", 44: "/", 45: "N", 46: "M", 47: ".",
        48: "⇥", 49: "Space", 50: "`", 51: "⌫", 65: "小键盘 .", 67: "小键盘 *",
        69: "小键盘 +", 75: "小键盘 /", 76: "小键盘 ↩", 78: "小键盘 −",
        81: "小键盘 =", 82: "小键盘 0", 83: "小键盘 1", 84: "小键盘 2", 85: "小键盘 3",
        86: "小键盘 4", 87: "小键盘 5", 88: "小键盘 6", 89: "小键盘 7", 91: "小键盘 8",
        92: "小键盘 9", 96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8",
        101: "F9", 103: "F11", 105: "F13", 106: "F16", 107: "F14", 109: "F10",
        111: "F12", 113: "F15", 114: "Help", 115: "↖", 116: "⇞", 117: "⌦",
        118: "F4", 119: "↘", 120: "F2", 121: "⇟", 122: "F1", 123: "←",
        124: "→", 125: "↓", 126: "↑", 64: "F17", 79: "F18", 80: "F19", 90: "F20"
    ]

    var isFunctionKey: Bool {
        guard let name = Self.keyNames[keyCode] else { return false }
        return name.hasPrefix("F") && Int(name.dropFirst()) != nil
    }

    var isValid: Bool {
        guard Self.keyNames[keyCode] != nil, modifiers & ~Self.allowedModifiers == 0 else { return false }
        // Bare letters and Shift-only shortcuts must remain available for typing.
        return isFunctionKey || modifiers & UInt32(cmdKey | optionKey | controlKey) != 0
    }

    var displayName: String {
        var prefix = ""
        for (mask, glyph) in [(controlKey, "⌃"), (optionKey, "⌥"), (shiftKey, "⇧"), (cmdKey, "⌘")] {
            if modifiers & UInt32(mask) != 0 { prefix += glyph }
        }
        return prefix + (Self.keyNames[keyCode] ?? "?")
    }

    init(keyCode: UInt32, modifiers: UInt32) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    init(event: NSEvent) {
        keyCode = UInt32(event.keyCode)
        var mask: UInt32 = 0
        for (flag, carbon) in [(NSEvent.ModifierFlags.command, cmdKey), (.option, optionKey),
                               (.control, controlKey), (.shift, shiftKey)] {
            if event.modifierFlags.contains(flag) { mask |= UInt32(carbon) }
        }
        modifiers = mask
    }

    static func load(from defaults: UserDefaults = .standard) -> Shortcut {
        guard let data = defaults.data(forKey: storageKey),
              let value = try? JSONDecoder().decode(Shortcut.self, from: data), value.isValid else {
            return .defaultShortcut
        }
        return value
    }

    func save(to defaults: UserDefaults = .standard) {
        guard isValid, let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}
