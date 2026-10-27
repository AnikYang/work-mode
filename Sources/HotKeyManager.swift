import AppKit
import Carbon
import os

final class HotKeyManager {
    private var reference: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private var localMonitor: Any?
    private var registeredShortcut: Shortcut?
    private var isPressed = false
    private let logger = Logger(subsystem: "local.anik.WorkMode", category: "HotKey")
    var onPress: (() -> Void)?

    init() {
        var events = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))
        ]
        // AppKit owns the Cocoa event loop. Receive hotkey events at the toolbox
        // dispatcher, before Cocoa routes them, rather than the Carbon app target.
        InstallEventHandler(GetEventDispatcherTarget(), { _, event, context in
            guard let event, let context else { return OSStatus(eventNotHandledErr) }
            let owner = Unmanaged<HotKeyManager>.fromOpaque(context).takeUnretainedValue()
            guard owner.reference != nil else { return OSStatus(eventNotHandledErr) }
            var identifier = EventHotKeyID()
            let result = GetEventParameter(event, EventParamName(kEventParamDirectObject),
                                           EventParamType(typeEventHotKeyID), nil,
                                           MemoryLayout<EventHotKeyID>.size, nil, &identifier)
            guard result == noErr, identifier.signature == 0x574D4F44, identifier.id == 1 else {
                return OSStatus(eventNotHandledErr)
            }
            owner.handlePress(GetEventKind(event) == UInt32(kEventHotKeyPressed))
            return noErr
        }, events.count, &events, Unmanaged.passUnretained(self).toOpaque(), &handler)

        // App-directed key events (including assistive input) may bypass Carbon.
        // Handle only our registered combination, and only inside our own app.
        // The same latch prevents a raw event and a Carbon event double-toggling.
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
            guard let self, self.reference != nil,
                  self.registeredShortcut == Shortcut(event: event) else { return event }
            if !event.isARepeat { self.handlePress(event.type == .keyDown) }
            return nil
        }
    }

    private func handlePress(_ pressed: Bool) {
        if !pressed {
            isPressed = false
        } else if !isPressed {
            isPressed = true
            logger.notice("Registered shortcut received")
            onPress?()
        }
    }

    /// Callers suspend the old registration while recording, then restore on cancel/failure.
    func register(_ shortcut: Shortcut) throws {
        guard shortcut.isValid else { throw HotKeyError(code: OSStatus(paramErr)) }
        guard handler != nil else { throw HotKeyError(code: OSStatus(eventInternalErr)) }
        unregister()
        var candidate: EventHotKeyRef?
        let result = RegisterEventHotKey(shortcut.keyCode, shortcut.modifiers,
                                        EventHotKeyID(signature: 0x574D4F44, id: 1),
                                        GetEventDispatcherTarget(), OptionBits(kEventHotKeyExclusive), &candidate)
        guard result == noErr else { throw HotKeyError(code: result) }
        reference = candidate
        registeredShortcut = shortcut
    }

    func unregister() {
        if let reference { UnregisterEventHotKey(reference) }
        reference = nil
        registeredShortcut = nil
        isPressed = false
    }

    deinit {
        unregister()
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        if let handler { RemoveEventHandler(handler) }
    }
}

struct HotKeyError: LocalizedError {
    let code: OSStatus
    var errorDescription: String? {
        "该快捷键无法注册，可能已被系统或其他应用占用。请换一组快捷键。（\(code)）"
    }
}
