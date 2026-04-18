# Windows 版本规划：WindowsIrland

## 背景

MacIrland 是一个 macOS AI CLI 会话观察器，通过 Dynamic Island 风格的界面显示 Claude Code 运行状态。

### 关键发现

Claude Code 的 hook 机制**完全跨平台**：
- Settings 文件路径相同：`~/.claude/settings.json`
- Hook JSON 协议完全相同
- Windows 支持 PowerShell 脚本：`"shell": "powershell"`

这意味着 **hook-first 架构天然支持 Windows**。

### 核心挑战

**macOS Observation 层**（AppleScript 读取 Terminal）没有直接等效物在 Windows 上。但：
- MacIrland 设计中 hook 是**主要**数据源
- Observation 只是**回退**方案
- 如果 hook 正常工作，observation 不是必须的

---

## 技术方案

### 架构选择：Tauri

| 对比项 | Electron | Tauri |
|--------|----------|-------|
| 体积 | ~150MB | ~10MB |
| 性能 | 较重 | 轻快 |
| 学习曲线 | 低 | 中（Rust） |
| Windows 托盘 | 简单 | 简单 |

**推荐理由**：
- 体积差距巨大（10MB vs 150MB）
- 性能好，Rust 后端
- 前端用 Web 技术，灵活
- UI 实现 Dynamic Island 风格圆形/胶囊界面容易

### 项目结构

```
WindowsIrland/
├── src/                    # Tauri 前端（React/Vue + TypeScript）
│   ├── main.ts            # 入口
│   ├── App.tsx            # 主组件
│   ├── components/        # UI 组件
│   │   ├── Island/       # Island 界面组件
│   │   ├── SessionList/   # 会话列表
│   │   └── StatusIcon/   # 状态图标
│   ├── hooks/            # React hooks
│   ├── services/         # 业务逻辑
│   │   ├── sessionStore.ts    # 核心状态管理
│   │   ├── hookBridge.ts      # Hook 通信
│   │   └── audioPlayer.ts     # 音频播放
│   └── styles/           # CSS/Tailwind
│
├── src-tauri/            # Tauri 后端（Rust）
│   ├── src/
│   │   ├── main.rs       # 入口
│   │   ├── lib.rs        # 库
│   │   ├── hook_server.rs    # Named Pipe hook 服务器
│   │   ├── observation.rs     # Windows Terminal 观察（待研究）
│   │   ├── audio.rs          # WASAPI 音频
│   │   └── tray.rs           # 系统托盘
│   ├── Cargo.toml
│   └── tauri.conf.json
│
├── scripts/
│   └── macirland-hook.ps1    # Windows PowerShell hook 脚本
│
├── SPEC.md               # 功能规格
├── README.md
└── package.json
```

### 核心模块设计

#### 1. Hook 服务器（Named Pipe）

macOS 用 Unix Domain Socket，Windows 用 Named Pipe。

```rust
// src-tauri/src/hook_server.rs
use std::path::PipePath;

pub struct HookServer {
    pipe_name: String,  // r"\\.\pipe\MacIrlandHook"
}

impl HookServer {
    pub fn new() -> Self {
        Self {
            pipe_name: r"\\.\pipe\MacIrlandHook".to_string(),
        }
    }

    pub fn start(&self, event_handler: impl Fn(HookEvent)) {
        // 使用 Windows Named Pipe API
        // 监听 hook 脚本发送的 JSON 事件
    }
}
```

#### 2. PowerShell Hook 脚本

```powershell
# scripts/macirland-hook.ps1
param(
    [string]$Event,
    [string]$SessionId,
    [string]$Cwd,
    [string]$Status
)

$pipeName = r"\\.\pipe\MacIrlandHook"
$eventJson = @{
    session_id = $SessionId
    cwd = $Cwd
    event = $Event
    status = $Status
    pid = $PID
    tty = $env:WT_SESSION_ID  # Windows Terminal session ID
} | ConvertTo-Json

# 发送到 Named Pipe
$client = New-Object System.IO.Pipes.NamedPipeClientStream(".", $pipeName)
$client.Connect(1000)
$writer = New-Object System.IO.StreamWriter($client)
$writer.Write($eventJson)
$writer.Flush()
$client.Close()
```

#### 3. 状态管理（前端）

```typescript
// src/services/sessionStore.ts
interface Session {
    id: string;
    sessionName: string;
    projectName: string;
    status: 'running' | 'waiting' | 'completed' | 'alert';
    hookSessionId?: string;
    tty?: string;
}

class SessionStore {
    sessions: Session[] = [];
    private hookBridge: HookBridge;

    processHookEvent(event: HookEvent) {
        // 处理 hook 事件，更新 session 状态
    }
}
```

#### 4. 托盘 UI

```typescript
// src/components/TrayIcon.tsx
// Dynamic Island 风格：圆形/胶囊形托盘图标
const TrayIcon = ({ status, sessions }) => {
    return (
        <div className="tray-icon">
            <div className={`status-dot ${status}`}>
                {status === 'running' && <AnimatedDots />}
                {status === 'waiting' && <PulsingDots />}
                {status === 'completed' && <CheckIcon />}
            </div>
            {sessions.length > 1 && (
                <span className="badge">{sessions.length}</span>
            )}
        </div>
    );
};
```

---

## 功能优先级

### P0 - MVP（必须）

1. **Hook 通信**
   - Named Pipe 服务器
   - PowerShell hook 脚本
   - JSON 事件解析

2. **基本 UI**
   - 系统托盘图标
   - 基础状态显示（运行中/等待/完成）
   - Hover 展开面板

3. **会话列表**
   - 显示 Claude Code 会话
   - 点击跳转 Windows Terminal tab

4. **音频反馈**
   - 任务完成提示音
   - 等待输入提示音

### P1 - 完善

5. **Observation 回退**（如果需要）
   - ConPTY 读取 Windows Terminal 输出
   - 状态判断逻辑

6. **多会话管理**
   - 多个 Claude Code 会话
   - 优先级排序

7. **声音开关**

### P2 - 增强

8. **设置面板**
9. **主题定制**
10. **通知集成**

---

## 开发步骤

### 阶段 1：项目初始化（1-2天）

- [ ] 创建 Tauri 项目：`npm create tauri-app WindowsIrland`
- [ ] 配置 Windows 托盘支持
- [ ] 设置构建工具链
- [ ] 验证空项目能运行

### 阶段 2：Hook 通信（2-3天）

- [ ] Rust Named Pipe 服务器
- [ ] PowerShell hook 脚本
- [ ] 前端事件处理
- [ ] 测试 hook 事件流

### 阶段 3：基础 UI（2-3天）

- [ ] 系统托盘图标
- [ ] 状态显示
- [ ] Hover 展开面板
- [ ] 会话列表

### 阶段 4：会话跳转（1-2天）

- [ ] Windows Terminal tab 跳转
- [ ] PowerShell 实现 Terminal 激活

### 阶段 5：音频（1天）

- [ ] WASAPI 音频播放
- [ ] 音效合成

### 阶段 6：测试与打磨（1-2天）

- [ ] 端到端测试
- [ ] Bug 修复
- [ ] 性能优化

---

## 工作量估算

| 阶段 | 内容 | 时间 |
|------|------|------|
| 1 | 项目初始化 | 1-2 天 |
| 2 | Hook 通信 | 2-3 天 |
| 3 | 基础 UI | 2-3 天 |
| 4 | 会话跳转 | 1-2 天 |
| 5 | 音频 | 1 天 |
| 6 | 测试打磨 | 1-2 天 |
| **总计** | | **8-15 天** |

---

## 代码复用

### 可直接复用

| 模块 | 说明 |
|------|------|
| HookEvent 数据结构 | JSON 协议相同 |
| TaskStateStore 逻辑 | 状态判断、session 合并 |
| ClaudeStatusJudge | 英文信号匹配 |
| SoundCue/SoundMode | 枚举定义 |
| DisplayFormatting | 格式化逻辑 |

### 需要重写

| 模块 | 替代方案 |
|------|----------|
| HookSocketServer | Named Pipe |
| ChiptuneSoundPlayer | WASAPI |
| ObservationService | ConPTY（待研究）|
| TerminalJumpService | PowerShell |
| SwiftUI UI | React/Vue + CSS |

---

## 待研究问题

1. **Windows Terminal observation**：是否有 API 读取另一个 tab 的内容？
2. **Windows Terminal 跳转**：如何通过 PowerShell 激活特定 tab？
3. **hook 事件完整性**：hook 事件是否足够覆盖所有状态？

---

## 分发方式

1. **GitHub Release**：打包 `.exe` 或 `.msi`
2. **winget**：可提交到 winget 官方仓库
3. **Scoop**：Windows 包管理器

---

## 参考资料

- [Tauri Windows 文档](https://tauri.app/distribute/windows/)
- [Windows Named Pipe](https://docs.microsoft.com/en-us/windows/win32/ipc/named-pipes)
- [Windows Terminal API](https://docs.microsoft.com/en-us/windows/terminal/api/)
