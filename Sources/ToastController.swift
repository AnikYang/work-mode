import AppKit
import SwiftUI

private final class ToastPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private final class ToastSettingsButton: NSButton {
    private let openSettings: () -> Void

    init(frame: NSRect, enabled: Bool, openSettings: @escaping () -> Void) {
        self.openSettings = openSettings
        super.init(frame: frame)
        title = ""
        isBordered = false
        focusRingType = .none
        target = self
        action = #selector(press)
        toolTip = "打开 Work Mode 设置"
        updateLabel(enabled: enabled)
    }

    func updateLabel(enabled: Bool) {
        setAccessibilityLabel(enabled ? "已启用 Work Mode，打开设置" : "已关闭 Work Mode，打开设置")
    }

    required init?(coder: NSCoder) { nil }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let radius = bounds.height / 2
        let capsule = NSBezierPath(roundedRect: bounds, xRadius: radius, yRadius: radius)
        guard capsule.contains(convert(point, from: superview)) else { return nil }
        return super.hitTest(point)
    }

    @objc private func press() { openSettings() }
}

private enum ToastLayout {
    static let capsuleSize = NSSize(width: 248, height: 58)
    static let shadowPadding: CGFloat = 20
    static var panelSize: NSSize {
        NSSize(width: capsuleSize.width + shadowPadding * 2,
               height: capsuleSize.height + shadowPadding * 2)
    }
}

private struct ToastView: View {
    let enabled: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        capsule
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.28 : 0.13), radius: 13, y: 5)
            .padding(ToastLayout.shadowPadding)
            .accessibilityHidden(true)
    }

    private var content: some View {
        HStack(spacing: 10) {
            Image(systemName: enabled ? "sun.max.fill" : "sun.max")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(enabled ? Color.white : Color.secondary)
                .frame(width: 36, height: 36)
                .background(enabled ? Color(red: 0.80, green: 0.43, blue: 0.08) : Color.primary.opacity(0.07), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(enabled ? "已启用Work Mode" : "已关闭Work Mode")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(enabled ? "电脑与屏幕保持唤醒" : "已恢复自动休眠")
                    .font(.system(size: 10.5)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "gearshape")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
        .padding(.leading, 10).padding(.trailing, 20)
        .frame(width: ToastLayout.capsuleSize.width, height: ToastLayout.capsuleSize.height)
    }

    @ViewBuilder private var capsule: some View {
        if #available(macOS 26.0, *) {
            content.glassEffect(.regular, in: Capsule())
        } else {
            content.background(.regularMaterial, in: Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.24), lineWidth: 0.5))
        }
    }
}

final class ToastController {
    private var panel: ToastPanel?
    private var dismissal: DispatchWorkItem?

    func updatePinnedToast(enabled: Bool) {
        guard dismissal == nil, let views = panel?.contentView?.subviews else { return }
        for view in views {
            (view as? NSHostingView<ToastView>)?.rootView = ToastView(enabled: enabled)
            (view as? ToastSettingsButton)?.updateLabel(enabled: enabled)
        }
    }

    func dismissPinnedToast() {
        guard dismissal == nil else { return }
        panel?.orderOut(nil)
        panel = nil
    }

    func show(enabled: Bool, openSettings: @escaping (NSPanel) -> Void) {
        dismissal?.cancel()
        panel?.orderOut(nil)
        panel = nil

        let mouse = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) ?? NSScreen.main else { return }
        let size = ToastLayout.panelSize
        // visibleFrame keeps the capsule below the menu bar and camera notch.
        let rect = NSRect(x: screen.visibleFrame.midX - size.width / 2,
                          y: screen.visibleFrame.maxY - size.height - 8,
                          width: size.width, height: size.height)
        let panel = ToastPanel(contentRect: rect, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.title = "Work Mode 提示"
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle, .stationary]
        let content = NSView(frame: NSRect(origin: .zero, size: size))
        let hostingView = NSHostingView(rootView: ToastView(enabled: enabled))
        hostingView.frame = content.bounds
        content.addSubview(hostingView)
        // Let the AppKit control receive the first click while another app is active.
        let buttonFrame = content.bounds.insetBy(dx: ToastLayout.shadowPadding, dy: ToastLayout.shadowPadding)
        let button = ToastSettingsButton(frame: buttonFrame, enabled: enabled) { [weak self, weak panel] in
            guard let self, let panel, self.panel === panel, let dismissal = self.dismissal else { return }
            dismissal.cancel()
            self.dismissal = nil
            panel.alphaValue = 1
            // Open after AppKit finishes dispatching the click on the transient panel.
            DispatchQueue.main.async { openSettings(panel) }
        }
        content.addSubview(button)
        panel.contentView = content
        panel.alphaValue = 0
        panel.setFrameOrigin(NSPoint(x: rect.minX, y: rect.minY + 8))
        panel.orderFrontRegardless()
        self.panel = panel

        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        NSAnimationContext.runAnimationGroup { context in
            context.duration = reduceMotion ? 0 : 0.24
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
            panel.animator().setFrameOrigin(rect.origin)
        }
        NSAccessibility.post(element: panel, notification: .announcementRequested,
                             userInfo: [.announcement: enabled ? "已启用Work Mode" : "已关闭Work Mode",
                                        .priority: NSAccessibilityPriorityLevel.high.rawValue])

        let dismissal = DispatchWorkItem { [weak self, weak panel] in
            guard let self, let panel, self.panel === panel else { return }
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = reduceMotion ? 0 : 0.22
                panel.animator().alphaValue = 0
            }, completionHandler: { [weak self, weak panel] in
                guard let self, let panel, self.panel === panel, self.dismissal != nil else { return }
                panel.orderOut(nil)
                self.panel = nil
                self.dismissal = nil
            })
        }
        self.dismissal = dismissal
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: dismissal)
    }
}
