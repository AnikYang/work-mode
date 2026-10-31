import SwiftUI

// Use the property-wrapper type explicitly with Command Line Tools SDKs.
private typealias ViewState<Value> = SwiftUI.State<Value>

/// The entire interface lives in the status item's transient dropdown.
struct MenuView: View {
    @ObservedObject var model: AppModel
    @ViewState<Bool> private var showsColors = false
    @ViewState<Bool> private var showsHelp = false
    @ViewState<String> private var hexDraft = ""
    @ViewState<Bool> private var colorError = false
    @FocusState private var colorFieldFocused: Bool

    private var accent: Color { Color(nsColor: model.accentColor.nsColor) }
    private var version: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "" }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Work Mode").font(.system(size: 14, weight: .semibold))
                    Text(model.isEnabled ? "已开启 · 电脑与屏幕保持唤醒" : "已关闭 · 自动休眠")
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("Work Mode", isOn: Binding(get: { model.isEnabled }, set: { _ in model.toggle() }))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .tint(accent)
                    .accessibilityLabel("Work Mode")
                    .accessibilityIdentifier("workModeToggle")
            }

            Divider()

            HStack {
                Text("快捷键")
                Spacer()
                if model.shortcut != .defaultShortcut && !model.isRecording {
                    Button("恢复 F6", action: model.resetShortcut)
                        .font(.system(size: 10)).buttonStyle(.borderless)
                }
                Button {
                    colorFieldFocused = false
                    model.beginRecording()
                } label: {
                    Text(model.isRecording ? "按下快捷键…" : model.shortcut.displayName)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .frame(minWidth: 42)
                }
                .accessibilityLabel(model.isRecording ? "录制中，按 Esc 取消" : "更改快捷键，当前为 \(model.shortcut.displayName)")
                .accessibilityIdentifier("shortcutRecorder")
            }
            if model.isRecording {
                Text("按 F1–F20 或组合键；Esc 取消。")
                    .font(.system(size: 10)).foregroundStyle(.secondary)
            }

            Button {
                model.cancelRecording()
                hexDraft = model.accentColor.hex
                colorError = false
                showsColors.toggle()
            } label: {
                HStack {
                    Text("亮起颜色")
                    Spacer()
                    Circle().fill(accent).frame(width: 12, height: 12)
                        .overlay(Circle().stroke(.primary.opacity(0.15), lineWidth: 0.5))
                    Image(systemName: showsColors ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .semibold)).foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("亮起颜色，\(model.accentColor.hex)")
            .accessibilityIdentifier("colorDisclosure")

            if showsColors {
                HStack(spacing: 10) {
                    ForEach(AccentColor.presets, id: \.color.hex) { preset in
                        Button {
                            model.setAccentColor(preset.color)
                            hexDraft = preset.color.hex
                            colorError = false
                        } label: {
                            Circle().fill(Color(nsColor: preset.color.nsColor))
                                .frame(width: 22, height: 22)
                                .overlay(Circle().stroke(.primary.opacity(0.2), lineWidth: 0.5))
                                .padding(3)
                                .overlay(Circle().stroke(model.accentColor == preset.color ? Color.primary.opacity(0.65) : .clear, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(preset.name)
                        .accessibilityValue(model.accentColor == preset.color ? "已选中" : "")
                    }
                    Spacer(minLength: 0)
                }
                HStack(spacing: 8) {
                    Text("色值").foregroundStyle(.secondary)
                    TextField("#RRGGBB", text: $hexDraft)
                        .font(.system(size: 11, design: .monospaced))
                        .textFieldStyle(.roundedBorder)
                        .focused($colorFieldFocused)
                        .onSubmit(applyColor)
                        .accessibilityLabel("自定义亮起颜色，十六进制色值")
                    Button("应用", action: applyColor)
                        .disabled(AccentColor(hex: hexDraft) == nil)
                }
                if colorError {
                    Text("请输入六位色值，例如 #E99A23。")
                        .font(.system(size: 10)).foregroundStyle(.red)
                }
            }

            if let error = model.errorMessage {
                Text(error).font(.system(size: 10)).foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("errorMessage")
            }

            Divider()

            Button {
                model.cancelRecording()
                showsHelp.toggle()
            } label: {
                HStack {
                    Text("关于与使用")
                    Spacer()
                    Image(systemName: showsHelp ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .semibold)).foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if showsHelp {
                VStack(alignment: .leading, spacing: 7) {
                    Text("Work Mode \(version) · MIT 开源")
                        .fontWeight(.medium)
                    Text("运行 AI 前按 \(model.shortcut.displayName) 开启，结束后再按一次。彩色为开启，灰色为关闭。")
                    Text(model.focusKeyCaptured ? "内置 F6 月亮键已接管；退出后恢复。" : "自定义快捷键可在其他应用中使用。")
                    Text("仅阻止闲置休眠。合盖、手动睡眠仍生效；不会静音通知。")
                    Link(destination: URL(string: "https://github.com/AnikYang/work-mode")!) {
                        VStack(alignment: .leading, spacing: 3) {
                            Label("GitHub · Star 支持", systemImage: "star")
                            Text("github.com/AnikYang/work-mode")
                        }
                    }
                    .accessibilityLabel("在 GitHub 打开 Work Mode，查看源码或点 Star 支持")
                }
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }

            Button("退出 Work Mode") { NSApp.terminate(nil) }
                .buttonStyle(.plain).foregroundStyle(.secondary)
        }
        .font(.system(size: 12))
        .padding(16)
        .frame(width: 280)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func applyColor() {
        guard let color = AccentColor(hex: hexDraft) else { colorError = true; return }
        model.setAccentColor(color)
        hexDraft = color.hex
        colorError = false
        colorFieldFocused = false
    }
}
