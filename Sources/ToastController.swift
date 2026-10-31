import AppKit
import SwiftUI

private final class ToastPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
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
            .accessibilityElement(children: .combine)
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
    private var generation = 0

    func show(enabled: Bool) {
        dismissal?.cancel()
        generation += 1
        let currentGeneration = generation
        panel?.orderOut(nil)

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
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle, .stationary]
        panel.contentView = NSHostingView(rootView: ToastView(enabled: enabled))
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
            guard let self, let panel, self.generation == currentGeneration else { return }
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = reduceMotion ? 0 : 0.22
                panel.animator().alphaValue = 0
            }, completionHandler: { [weak self, weak panel] in
                guard self?.generation == currentGeneration else { return }
                panel?.orderOut(nil)
                self?.panel = nil
            })
        }
        self.dismissal = dismissal
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: dismissal)
    }
}
