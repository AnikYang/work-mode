<p align="center"><img src="docs/assets/app-icon.png" width="100" alt="Work Mode 太阳图标"></p>

<h1 align="center">Work Mode</h1>
<p align="center">运行 AI 时，让 Mac 保持清醒。</p>
<p align="center">原生 Swift · Apple Silicon · macOS 14+ · MIT</p>
<p align="center">简体中文 · <a href="README.en.md">English</a></p>

Work Mode 是一个轻量的 macOS 菜单栏应用。开始模型推理、内容生成或长时间 AI 任务之前，按一下 **F6**，让电脑和屏幕保持唤醒；任务结束后，再按一下恢复自动休眠。

它把 MacBook 键盘上的 **F6 勿扰键**变成 Work Mode 开关：直接按月亮图标所在的键，不需要 Fn。用“保持清醒”替代这个按键原来的用途。

<p align="center"><img src="docs/assets/work-mode-hud.png" width="420" alt="启用 Work Mode 后的太阳图标玻璃胶囊提示"></p>

## 功能

- **为 AI 长任务保持唤醒**：同时阻止电脑和屏幕因闲置自动休眠。
- **接管 F6 勿扰键**：默认接管内置键盘的月亮键，更换快捷键或正常退出后恢复原功能。
- **自定义全局快捷键**：支持 F1–F20，以及带 Command、Option 或 Control 的组合键。
- **原生太阳胶囊**：顶部提示启用 / 关闭状态，约 3 秒后淡出；macOS 26+ 使用原生玻璃效果。
- **轻量运行**：无第三方运行时依赖，无轮询、模拟鼠标输入或常驻子进程。
- **无需联网与账号**：没有遥测，不读取 AI 对话，不需要辅助功能或输入监控权限。

Work Mode 由你手动开启，不会自动判断 AI 是否正在运行。“替代勿扰”指替代 F6 的按键用途；应用不会静音通知，也不会改变系统当前的专注模式状态。

## 安装与使用

从 [Releases](https://github.com/AnikYang/work-mode/releases) 获取可用的 Apple Silicon 构建，或按下方步骤从源码构建。

1. 打开 `Work Mode.app`，默认处于关闭状态。
2. 按 **F6 月亮键**进入 Work Mode，屏幕顶部显示“已启用Work Mode”。
3. 再按一次 F6 关闭。菜单栏**实心太阳**表示启用，**空心太阳**表示关闭。
4. 在设置中点击快捷键按钮录制新按键，按 Esc 取消；“恢复 F6”恢复默认。
5. 关闭设置窗口后仍在菜单栏运行。通过菜单栏退出会释放防休眠请求并恢复月亮键。

当前发布构建为本地 ad-hoc 签名，尚未进行 Apple 开发者签名与公证，也可以在本机直接构建。软件界面目前使用简体中文。

## 构建与验证

需要 Apple Silicon Mac、macOS 14+，以及 **macOS 26 或更新的 SDK**（Xcode 26+ 或对应的 Command Line Tools）。

```sh
git clone https://github.com/AnikYang/work-mode.git
cd work-mode
bash scripts/build.sh
bash scripts/test.sh
open "build/Work Mode.app"
bash scripts/package.sh  # 生成版本 ZIP，并输出 SHA-256
```

无需安装第三方包。产物位于 `build/Work Mode.app`。

默认测试覆盖快捷键持久化、注册与冲突、重复事件去重、电源请求的创建和释放，以及键位映射的保留与恢复逻辑。测试会短暂注册测试快捷键及电源请求，**不会修改真实键盘映射**。

在带内置键盘的 MacBook 桌面会话中，可以主动运行硬件测试：

```sh
WORKMODE_HARDWARE_TESTS=1 bash scripts/test.sh
```

硬件测试会暂时映射内置月亮键，读取系统结果，再恢复原映射。实体键行为仍应手动检查：切到其他应用后按 F6，确认 Work Mode 切换且系统勿扰状态没有改变。

## 工作边界

- 阻止的是**闲置导致的自动休眠**；合盖、手动睡眠、关机和低电量保护仍由 macOS 控制。
- 不改变屏幕保护程序、锁屏策略、网络连接或 AI 服务自身的限制。
- 月亮键接管目前面向 MacBook **内置键盘**。外接键盘可使用标准 F6 或自定义组合键。
- 正常退出会立即恢复原键位；若被强制终止，重新打开应用后再正常退出即可恢复，系统重启也会清除临时映射。
- 长任务结束后请关闭 Work Mode，以恢复电脑与屏幕的自动休眠。

## 实现与贡献

SwiftUI 和 AppKit 提供界面；Carbon 处理全局快捷键；IOKit 创建 `PreventUserIdleSystemSleep` 与 `PreventUserIdleDisplaySleep` 电源请求。键位接管使用 Apple [TN2450](https://developer.apple.com/library/archive/technotes/tn2450/) 接口，只改变内置键盘的 System Do Not Disturb 映射并保留原映射。

欢迎提交 Issue 和 Pull Request，详见 [贡献指南](CONTRIBUTING.md)。本项目采用 [MIT License](LICENSE)。
