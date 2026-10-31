import AppKit
import SwiftUI

// Keep the old notification name so an already running older copy can still respond.
private let showMenuNotification = Notification.Name("local.anik.WorkMode.showSettings")

final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private var model: AppModel!
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private var keyMonitor: Any?
    private let toast = ToastController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureEditingMenu()
        model = AppModel()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.target = self
        statusItem.button?.action = #selector(toggleMenu)
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])

        popover.behavior = .transient
        popover.animates = false
        popover.delegate = self
        let controller = NSHostingController(rootView: MenuView(model: model))
        controller.sizingOptions = [.preferredContentSize]
        popover.contentViewController = controller

        model.onStatusChange = { [weak self] in self?.updateStatus() }
        model.onFeedback = { [weak self] enabled in
            guard let self else { return }
            // The open dropdown already shows the result; avoid a second prompt.
            if !self.popover.isShown { self.toast.show(enabled: enabled) }
        }
        updateStatus()

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.popover.isShown,
                  event.window === self.popover.contentViewController?.view.window else { return event }
            if self.model.isRecording {
                self.model.record(event)
                return nil
            }
            if event.keyCode == 53 { self.popover.performClose(nil); return nil }
            return event
        }
        DistributedNotificationCenter.default().addObserver(self, selector: #selector(showMenu),
                                                            name: showMenuNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(didWake),
                                                          name: NSWorkspace.didWakeNotification, object: nil)
        showMenu()
    }

    private func configureEditingMenu() {
        // Accessory apps still need the standard responder-chain editing commands.
        let menu = NSMenu()
        let editing = NSMenuItem()
        let submenu = NSMenu(title: "编辑")
        submenu.addItem(withTitle: "剪切", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        submenu.addItem(withTitle: "复制", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        submenu.addItem(withTitle: "粘贴", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        submenu.addItem(withTitle: "全选", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editing.submenu = submenu
        menu.addItem(editing)
        NSApp.mainMenu = menu
    }

    private func updateStatus() {
        guard let button = statusItem.button else { return }
        button.image = StatusIcon.make(enabled: model.isEnabled, color: model.accentColor)
        let state = model.isEnabled ? "已启用 · 电脑与屏幕保持唤醒" : "已关闭"
        button.toolTip = "Work Mode \(state)"
        button.setAccessibilityLabel(button.toolTip)
    }

    @objc private func toggleMenu() {
        if popover.isShown { popover.performClose(nil) } else { showMenu() }
    }

    @objc private func showMenu() {
        guard let button = statusItem.button, !popover.isShown else { return }
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    func popoverDidClose(_ notification: Notification) { model.cancelRecording() }

    @objc private func didWake() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in self?.model.refreshKeyboard() }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMenu()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        DistributedNotificationCenter.default().removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        model.shutdown()
    }
}

// A development build and an installed copy must not compete for the same hotkey.
if let existing = NSRunningApplication.runningApplications(withBundleIdentifier: "local.anik.WorkMode")
    .first(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier && !$0.isTerminated }) {
    DistributedNotificationCenter.default().postNotificationName(showMenuNotification, object: nil, deliverImmediately: true)
    existing.activate(options: [])
    exit(0)
}

let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.run()
