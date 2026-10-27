import AppKit
import SwiftUI

private let showSettingsNotification = Notification.Name("local.anik.WorkMode.showSettings")

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var model: AppModel!
    private var statusItem: NSStatusItem!
    private var settingsWindow: NSWindow?
    private var keyMonitor: Any?
    private let toast = ToastController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        model = AppModel()
        model.onStatusChange = { [weak self] in
            self?.updateMenu()
            if self?.model.errorMessage != nil { self?.showSettings() }
        }
        model.onFeedback = { [weak self] enabled in self?.toast.show(enabled: enabled) }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        configureAppMenu()
        updateMenu()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.model.isRecording, event.window === self.settingsWindow else { return event }
            self.model.record(event)
            return nil
        }
        DistributedNotificationCenter.default().addObserver(self, selector: #selector(showSettings),
                                                            name: showSettingsNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(didWake),
                                                          name: NSWorkspace.didWakeNotification, object: nil)
        showSettings()
    }

    private func configureAppMenu() {
        let mainMenu = NSMenu()
        let applicationItem = NSMenuItem()
        let applicationMenu = NSMenu(title: "Work Mode")
        let settings = NSMenuItem(title: "设置…", action: #selector(showSettings), keyEquivalent: ",")
        settings.target = self
        applicationMenu.addItem(settings)
        let close = NSMenuItem(title: "关闭窗口", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        applicationMenu.addItem(close)
        applicationMenu.addItem(.separator())
        let quit = NSMenuItem(title: "退出 Work Mode", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        applicationMenu.addItem(quit)
        applicationItem.submenu = applicationMenu
        mainMenu.addItem(applicationItem)
        NSApp.mainMenu = mainMenu
    }

    private func updateMenu() {
        let enabled = model.isEnabled
        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: enabled ? "sun.max.fill" : "sun.max", accessibilityDescription: "Work Mode")
            image?.isTemplate = true
            button.image = image
            button.toolTip = enabled ? "Work Mode 已启用 · 电脑与屏幕保持唤醒" : "Work Mode 已关闭"
            button.setAccessibilityLabel(button.toolTip)
        }
        let menu = NSMenu()
        let status = NSMenuItem(title: enabled ? "● Work Mode 已启用" : "Work Mode 待命中", action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)
        let action = NSMenuItem(title: enabled ? "关闭 Work Mode" : "启用 Work Mode", action: #selector(toggle), keyEquivalent: "")
        action.target = self
        menu.addItem(action)
        let shortcutStatus = model.isRecording ? "快捷键录制中…" : model.shortcutAvailable ? "快捷键：\(model.shortcut.displayName)" : "快捷键不可用 · 请重新设置"
        let shortcut = NSMenuItem(title: shortcutStatus, action: nil, keyEquivalent: "")
        shortcut.isEnabled = false
        menu.addItem(shortcut)
        menu.addItem(.separator())
        let settings = NSMenuItem(title: "设置…", action: #selector(showSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "退出 Work Mode", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        statusItem.menu = menu
    }

    @objc private func toggle() { model.toggle() }
    @objc private func quit() { NSApp.terminate(nil) }
    @objc private func didWake() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in self?.model.refreshKeyboard() }
    }

    @objc func showSettings() {
        if settingsWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 560),
                                  styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
                                  backing: .buffered, defer: false)
            window.title = "Work Mode"
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.contentView = NSHostingView(rootView: SettingsView(model: model).padding(.top, 20))
            window.setContentSize(NSSize(width: 480, height: 580))
            window.center()
            settingsWindow = window
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) { model.cancelRecording() }
    func windowDidResignKey(_ notification: Notification) { model.cancelRecording() }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
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
    DistributedNotificationCenter.default().postNotificationName(showSettingsNotification, object: nil, deliverImmediately: true)
    existing.activate(options: [])
    exit(0)
}

let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.run()
