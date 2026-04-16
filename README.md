# MacIrland

macOS AI CLI 会话观察器。观察 Claude Code 在终端里的运行状态，以 island-first 界面的形式呈现在你的 mac 顶部菜单栏。

## 功能特性

- **顶部 Island 状态显示** — 实时显示 Claude Code 会话状态（运行中、等待输入、已完成、告警等）
- **多会话管理** — 同时观察多个 Claude Code tab，点击即可跳转到对应终端窗口
- **智能状态识别** — 自动分析 transcript 判断真实状态，无需猜测
- **声音提醒** — 任务完成、等待回复、出现错误时播放提示音
- **一键回复** — 直接从 island 向 Claude Code 会话发送指令
- **跨终端支持** — 支持 Terminal.app 和 iTerm2

## Island 界面说明

| 状态 | 图标 | 含义 |
|------|------|------|
| 绿色动画点 | terminal 图标 + 4 个逐步亮起的点 | Claude Code 正在执行任务 |
| 橙色省略号脉冲 | 等待输入 | 等待你的下一步指示 |
| 橙色对勾 | 已完成 | 任务执行完毕 |
| 红色边框 | 告警 | 出现错误或警告 |

**交互：**
- 鼠标悬停到 island → 展开显示当前会话详情和所有会话列表
- 点击会话行 → 跳转到对应的 Terminal/iTerm2 tab
- 移动鼠标离开 → 收起 island
- hover expand 右上角可开关声音提示

## 安装

### 方式一：使用已编译版本

```bash
open ~/Applications/MacIrland.app
```

如果是首次安装，需要在**系统设置 > 隐私与安全性**中允许运行。

### 方式二：从源码构建

```bash
git clone https://github.com/JuanWithJunJie/ai-dynamic-island.git
cd ai-dynamic-island
swift build --configuration release
# 然后将 .build/arm64-apple-macosx/release/MacIrland 打包为 app
```

### 启用 Claude Code Hook

安装 hook 让 MacIrland 获得完整功能：

```bash
bash Scripts/install-hooks.sh
```

然后重启 Claude Code。App 启动时会自动检测并更新 hook 脚本版本。

### 权限授权

首次运行时会提示需要以下权限：

1. **自动化权限** — 用于读取 Terminal/iTerm2 会话状态和发送指令
   - 系统设置 > 隐私与安全性 > 隐私 > 自动化
   - 找到 MacIrland，勾选 Terminal 和 iTerm2

## 使用

1. 启动 MacIrland：`open ~/Applications/MacIrland.app`
2. 打开一个 Terminal/iTerm2 窗口
3. 启动 Claude Code：`claude` 或 `claude code`
4. MacIrland 会自动检测并显示会话状态

## 项目结构

```
MacIrlandApp/       — App 入口、Island 协调器、状态栏控制
MacIrlandKit/       — 核心模型、服务、SwiftUI 视图
  Core/            — TaskSession、TaskStateStore 状态管理
  Adapters/        — CLI 适配器（Claude Code、Codex、Gemini）
  Services/        — Observation、TerminalJump、Feedback 服务
  Features/        — Island、Panel、Diagnostics UI 组件
MacIrlandTests/    — 单元测试
Scripts/           — Hook 安装脚本、开发运行脚本
```

## 技术栈

- Swift + SwiftUI + AppKit
- `@Observable` 状态管理
- Hook-first 架构（Unix Domain Socket + AppleScript 回退）
- AppleScript（Terminal/iTerm2 读写）
- AVFoundation（8-bit Chiptune 音效合成）

## 构建与测试

```bash
# 构建
swift build --package-path .

# 测试
swift test --package-path .

# 开发模式运行
./Scripts/run-dev-app.sh
```

## 当前限制

- 需要 macOS 14+
- 仅支持 Claude Code，Codex / Gemini 为模拟链路
- 依赖 Terminal/iTerm2 的 accessibility 权限

## 许可证

MIT
