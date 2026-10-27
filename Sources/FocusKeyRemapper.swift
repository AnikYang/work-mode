import AppKit
import IOKit.hid
import IOKit.hidsystem

/// Uses Apple's TN2450 property API. No event tap, input monitoring, or key logging.
/// Only the built-in keyboard's System Do Not Disturb usage is replaced.
final class FocusKeyRemapper {
    static let property = "UserKeyMapping"
    static let sourceKey = "HIDKeyboardModifierMappingSrc"
    static let destinationKey = "HIDKeyboardModifierMappingDst"
    static let focusUsage: UInt64 = 0x10000009B // Generic Desktop / System Do Not Disturb
    static let f6Usage: UInt64 = 0x70000003F    // Keyboard / F6
    static let backupKey = "focusKeyOriginalMappings.v1"

    private let client = IOHIDEventSystemClientCreateSimpleClient(nil)
    private let defaults: UserDefaults
    private var originals: [String: Data]
    private(set) var isActive = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        originals = defaults.dictionary(forKey: Self.backupKey) as? [String: Data] ?? [:]
        // Recover a mapping left behind by a previous unexpected termination.
        restore()
    }

    private var keyboards: [IOHIDServiceClient] {
        let services = IOHIDEventSystemClientCopyServices(client) as? [IOHIDServiceClient] ?? []
        return services.filter {
            IOHIDServiceClientConformsTo($0, UInt32(kHIDPage_GenericDesktop), UInt32(kHIDUsage_GD_Keyboard)) != 0
                && (IOHIDServiceClientCopyProperty($0, "Built-In" as CFString) as? NSNumber)?.boolValue == true
        }
    }

    private func identifier(_ service: IOHIDServiceClient) -> String {
        (IOHIDServiceClientGetRegistryID(service) as! NSNumber).stringValue
    }

    private func mappings(_ service: IOHIDServiceClient) -> [[String: Any]] {
        IOHIDServiceClientCopyProperty(service, Self.property as CFString) as? [[String: Any]] ?? []
    }

    static func isFocusMapping(_ entry: [String: Any]) -> Bool {
        (entry[sourceKey] as? NSNumber)?.uint64Value == focusUsage
    }

    static func isOwnedMapping(_ entry: [String: Any]) -> Bool {
        isFocusMapping(entry) && (entry[destinationKey] as? NSNumber)?.uint64Value == f6Usage
    }

    static func replacingFocus(in entries: [[String: Any]]) -> [[String: Any]] {
        entries.filter { !isFocusMapping($0) } + [
            [sourceKey: NSNumber(value: focusUsage), destinationKey: NSNumber(value: f6Usage)]
        ]
    }

    static func restoringFocus(in entries: [[String: Any]], original: [[String: Any]]) -> [[String: Any]] {
        // Don't overwrite another tool's later change to this key.
        guard entries.contains(where: isOwnedMapping) else { return entries }
        return entries.filter { !isFocusMapping($0) } + original
    }

    func activate() throws {
        let devices = keyboards
        guard !devices.isEmpty else { throw FocusKeyError("没有找到内置键盘，暂时无法接管月亮键。") }
        for service in devices {
            let id = identifier(service)
            let current = mappings(service)
            if current.contains(where: Self.isOwnedMapping), originals[id] != nil { continue }
            let original = current.filter(Self.isFocusMapping)
            originals[id] = try PropertyListSerialization.data(fromPropertyList: original, format: .binary, options: 0)
            // Persist before writing so a later launch can recover after a crash.
            saveOriginals()
            let replacement = Self.replacingFocus(in: current)
            guard IOHIDServiceClientSetProperty(service, Self.property as CFString, replacement as CFArray),
                  mappings(service).contains(where: Self.isOwnedMapping) else {
                restore()
                throw FocusKeyError("系统没有接受月亮键映射，请退出后重新打开 Work Mode。")
            }
        }
        isActive = true
    }

    func restore() {
        for service in keyboards {
            let id = identifier(service)
            guard let data = originals[id],
                  let original = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [[String: Any]] else { continue }
            let current = mappings(service)
            if !current.contains(where: Self.isOwnedMapping) {
                originals.removeValue(forKey: id)
                continue
            }
            let restored = Self.restoringFocus(in: current, original: original)
            if IOHIDServiceClientSetProperty(service, Self.property as CFString, restored as CFArray) {
                originals.removeValue(forKey: id)
            }
        }
        isActive = false
        saveOriginals()
    }

    private func saveOriginals() {
        if originals.isEmpty { defaults.removeObject(forKey: Self.backupKey) }
        else { defaults.set(originals, forKey: Self.backupKey) }
    }

    deinit { restore() }
}

struct FocusKeyError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}
