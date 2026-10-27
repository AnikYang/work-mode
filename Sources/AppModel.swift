import AppKit
import Combine

final class AppModel: ObservableObject {
    @Published private(set) var isEnabled = false
    @Published private(set) var shortcut = Shortcut.load()
    @Published private(set) var isRecording = false
    @Published private(set) var shortcutAvailable = false
    @Published private(set) var focusKeyCaptured = false
    @Published var errorMessage: String?
    var onStatusChange: (() -> Void)?
    var onFeedback: ((Bool) -> Void)?

    private let power = PowerManager()
    private let hotKey = HotKeyManager()
    private let focusKey = FocusKeyRemapper()

    init() {
        hotKey.onPress = { [weak self] in self?.toggle() }
        restoreShortcut()
    }

    func toggle() {
        do {
            if isEnabled { power.disable() } else { try power.enable() }
            isEnabled = power.isEnabled
            errorMessage = nil
            onStatusChange?()
            onFeedback?(isEnabled)
        } catch {
            errorMessage = error.localizedDescription
            onStatusChange?()
        }
    }

    func beginRecording() {
        guard !isRecording else { cancelRecording(); return }
        errorMessage = nil
        hotKey.unregister()
        shortcutAvailable = false
        isRecording = true
        onStatusChange?()
    }

    func cancelRecording() {
        guard isRecording else { return }
        isRecording = false
        errorMessage = nil
        restoreShortcut()
        onStatusChange?()
    }

    func record(_ event: NSEvent) {
        guard isRecording, !event.isARepeat else { return }
        if event.keyCode == 53 { cancelRecording(); return }
        let candidate = Shortcut(event: event)
        guard candidate.isValid else {
            errorMessage = "请使用 F1–F20，或带 ⌘、⌥、⌃ 的组合键。按 Esc 取消。"
            return
        }
        setShortcut(candidate)
    }

    func resetShortcut() { setShortcut(.defaultShortcut) }

    private func setShortcut(_ candidate: Shortcut) {
        isRecording = false
        do {
            try hotKey.register(candidate)
            shortcut = candidate
            shortcut.save()
            shortcutAvailable = true
            errorMessage = nil
            updateFocusKey()
        } catch {
            errorMessage = error.localizedDescription
            restoreShortcut()
        }
        onStatusChange?()
    }

    private func restoreShortcut() {
        do {
            try hotKey.register(shortcut)
            shortcutAvailable = true
            updateFocusKey()
        } catch {
            shortcutAvailable = false
            errorMessage = error.localizedDescription
            focusKey.restore()
            focusKeyCaptured = false
        }
    }

    private func updateFocusKey() {
        do {
            if shortcut == .defaultShortcut { try focusKey.activate() }
            else { focusKey.restore() }
            focusKeyCaptured = focusKey.isActive
        } catch {
            focusKeyCaptured = false
            errorMessage = error.localizedDescription
        }
    }

    func refreshKeyboard() {
        guard !isRecording, shortcutAvailable else { return }
        updateFocusKey()
        onStatusChange?()
    }

    func shutdown() {
        hotKey.unregister()
        focusKey.restore()
        power.disable()
    }
}
