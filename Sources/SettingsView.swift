import SwiftUI

private let workAmber = Color(red: 0.75, green: 0.40, blue: 0.07)

struct SettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(spacing: 14) {
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 27, weight: .medium))
                    .foregroundStyle(workAmber)
                    .frame(width: 58, height: 58)
                    .background(workAmber.opacity(0.10), in: RoundedRectangle(cornerRadius: 17))
                VStack(alignment: .leading, spacing: 5) {
                    Text("Work Mode").font(.system(size: 25, weight: .semibold, design: .rounded))
                    Text("运行 AI 时，让 Mac 保持清醒。")
                        .font(.system(size: 13)).foregroundStyle(.secondary)
                }
                Spacer()
                Text("原生 · 轻量").font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)
            }

            VStack(alignment: .leading, spacing: 21) {
                HStack {
                    HStack(spacing: 7) {
                        Circle().fill(model.isEnabled ? workAmber : Color.secondary.opacity(0.5))
                            .frame(width: 7, height: 7)
                        Text(model.isEnabled ? "WORK MODE 已启用" : "WORK MODE 待命中")
                            .font(.system(size: 10, weight: .semibold)).tracking(1)
                            .foregroundStyle(model.isEnabled ? workAmber : .secondary)
                    }
                    Spacer()
                    Image(systemName: model.isEnabled ? "sun.max.fill" : "sun.max")
                        .font(.system(size: 18)).foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 7) {
                    Text(model.isEnabled ? "Mac 已保持清醒。" : "开始 AI 任务前，按一下。")
                        .font(.system(size: 21, weight: .semibold))
                    Text(model.isEnabled ? "电脑与屏幕持续唤醒，直到你手动关闭。" : "运行模型、生成内容或执行长时间 AI 任务。")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                }
                Button(action: model.toggle) {
                    HStack(spacing: 8) {
                        Image(systemName: "power").font(.system(size: 12, weight: .semibold))
                        Text(model.isEnabled ? "关闭 Work Mode" : "启用 Work Mode")
                            .font(.system(size: 13, weight: .semibold))
                        Spacer()
                        Text(model.shortcut.displayName)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .opacity(0.8)
                    }
                    .padding(.horizontal, 15).frame(height: 42)
                    .foregroundStyle(.white)
                    .background(workAmber, in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("workModeToggle")
            }
            .padding(21)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(workAmber.opacity(model.isEnabled ? 0.27 : 0.07), lineWidth: 1))

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("全局快捷键").font(.system(size: 13, weight: .semibold))
                        Text(model.focusKeyCaptured ? "直接按月亮键，不需要按 Fn。" : "在任何应用中，按一下即可切换。")
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(action: model.beginRecording) {
                        Text(model.isRecording ? "按下新快捷键…" : model.shortcut.displayName)
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .frame(minWidth: 74, minHeight: 38)
                            .padding(.horizontal, 10)
                            .foregroundStyle(model.isRecording ? workAmber : .primary)
                            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 9))
                            .overlay(RoundedRectangle(cornerRadius: 9)
                                .stroke(model.isRecording ? workAmber : Color.primary.opacity(0.13), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(model.isRecording ? "正在录制快捷键，按 Escape 取消" : "更改快捷键，当前为 \(model.shortcut.displayName)")
                    .accessibilityIdentifier("shortcutRecorder")
                }
                HStack {
                    Text(model.isRecording ? "支持 F1–F20 或组合键 · Esc 取消" : "点击右侧按键即可修改")
                        .font(.system(size: 11)).foregroundStyle(.tertiary)
                    Spacer()
                    Button(model.isRecording ? "取消" : "恢复 F6") {
                        if model.isRecording { model.cancelRecording() } else { model.resetShortcut() }
                    }
                    .font(.system(size: 11)).buttonStyle(.plain).foregroundStyle(workAmber)
                }
            }

            if let error = model.errorMessage {
                Text(error).font(.system(size: 11)).foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("errorMessage")
            }

            Spacer(minLength: 0)
            Divider().opacity(0.5)
            VStack(alignment: .leading, spacing: 6) {
                Label(model.focusKeyCaptured ? "F6 月亮键已交给 Work Mode，退出后恢复勿扰功能。" : model.shortcut == .defaultShortcut ? "月亮键接管未就绪，请查看上方提示。" : "使用自定义快捷键时，月亮键保持系统原有功能。", systemImage: "keyboard")
                Text("关闭窗口后仍在菜单栏运行；退出会恢复按键与自动休眠。")
            }
            .font(.system(size: 10)).foregroundStyle(.secondary)
        }
        .padding(28)
        .frame(width: 480, height: 560)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
