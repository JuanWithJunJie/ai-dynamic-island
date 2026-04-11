# MacIrland

macOS AI CLI 会话观察器。观察 Claude Code 在终端里的运行状态，以 island-first 界面的形式呈现。

## 产品形态

- **Island 顶部状态层** — compact / hover expand / highlighted 三态，显示当前最高优先级会话
- **Panel 详情层** — 点击 status bar 入口展开，展示会话列表、详情和回复能力
- **Menu Bar / Dock** — island 不可见时的 fallback 入口

## 核心功能

- 真实 observation：Hook socket server 接收 Claude Code 生命周期事件，AppleScript 读取 Terminal/iTerm2 transcript
- 真实 reply bridge：通过 AppleScript 向 Claude Code 终端会话发送回复
- 状态自动判断：基于 normalized transcript tail 的 signal scoring，识别 running / waitingInput / replyAvailable / completed / alert / failed 等状态
- 声音反馈：Chiptune 音效（任务开始、等待回复、任务完成、失败告警），hover expand 面板可开关
- 多会话支持：Claude Code 多 tab 同时运行时，hover expand 显示所有会话，点击跳转对应 Terminal tab

## 技术栈

- Swift + SwiftUI + AppKit
- `@Observable` 状态管理
- Unix socket IPC（Hook socket server）
- AppleScript（Terminal.app / iTerm2 observation + reply）
- AVFoundation（Chiptune 声音合成）

## 快速启动

```bash
cd /Users/lijunjie/Documents/AIproject/macirland
./Scripts/run-dev-app.sh
```

## 验证

```bash
swift build --package-path "/Users/lijunjie/Documents/AIproject/macirland"
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland"
```

## 项目结构

```
MacIrlandApp/   — App lifecycle, IslandCoordinator, RefreshCoordinator, StatusBarController
MacIrlandKit/   — Core models, adapters, services, SwiftUI views
MacIrlandTests/ — Unit tests
docs/           — Product specs and design docs
Scripts/        — Hook installer, dev runner
```

## 当前限制

- Observation 依赖 Terminal.app / iTerm2 的 accessibility 权限（需要用户手动在系统设置中授权）
- Reply 草稿仅保存在当前 app 运行期
- Codex / Gemini 为模拟链路，非真实 observation
