import AppKit

struct AccentColor: Equatable {
    static let storageKey = "activeIconColor.v1"
    static let defaultColor = AccentColor(hex: "E99A23")!
    static let presets: [(name: String, color: AccentColor)] = [
        ("琥珀", defaultColor), ("珊瑚", AccentColor(hex: "F06B65")!),
        ("绿色", AccentColor(hex: "46B981")!), ("蓝色", AccentColor(hex: "519CF0")!),
        ("紫色", AccentColor(hex: "B18AE8")!)
    ]

    let hex: String

    init?(hex: String) {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") { value.removeFirst() }
        guard value.utf8.count == 6,
              value.utf8.allSatisfy({ (48...57).contains($0) || (65...70).contains($0) || (97...102).contains($0) }) else { return nil }
        self.hex = "#" + value.uppercased()
    }

    var nsColor: NSColor {
        let value = UInt32(hex.dropFirst(), radix: 16)!
        return NSColor(srgbRed: CGFloat((value >> 16) & 255) / 255,
                       green: CGFloat((value >> 8) & 255) / 255,
                       blue: CGFloat(value & 255) / 255, alpha: 1)
    }

    static func load(from defaults: UserDefaults = .standard) -> AccentColor {
        defaults.string(forKey: storageKey).flatMap { AccentColor(hex: $0) } ?? defaultColor
    }

    func save(to defaults: UserDefaults = .standard) { defaults.set(hex, forKey: Self.storageKey) }
}

enum StatusIcon {
    static func make(enabled: Bool, color: AccentColor) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let symbol = NSImage(systemSymbolName: enabled ? "sun.max.fill" : "sun.max", accessibilityDescription: nil)?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 16, weight: .medium))
        let tint = enabled ? color.nsColor : NSColor(srgbRed: 0.55, green: 0.55, blue: 0.55, alpha: 1)
        let image = NSImage(size: size, flipped: false) { rect in
            symbol?.draw(in: rect)
            tint.setFill()
            rect.fill(using: .sourceAtop)
            return true
        }
        // Template images discard custom colors when drawn in the menu bar.
        image.isTemplate = false
        return image
    }
}
