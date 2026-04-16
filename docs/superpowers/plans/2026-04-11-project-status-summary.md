# MacIrland 项目进度总结

**最后更新：** 2026-04-11
**分支：** `feature/runtime-timeline-history`
**测试状态：** 214 tests passing

---

## 一、产品形态

macOS AI CLI 会话观察器，两层 UI + fallback：

1. **Island（顶部）**：compact / hoverExpand / highlighted 三态
2. **Panel（详情）**：小尺寸 detail sheet，作为第二层
3. **Menu bar / Dock**：fallback

主要链路：**Claude Code + Terminal.app / iTerm2**

---

## 二、已实现功能

### Island UI
- 三态：`compact`（小条）/ `hoverExpand`（悬停展开）/ `highlighted`（自动弹出）
- hoverExpand：悬停 200ms 后展开，显示当前 session 详情 + tray 列表；离开后自动折叠
- highlighted：根据 attention 优先级自动弹出，完成后自动折叠
- 点击行为：**已禁用 panel 弹出**，只做本地 cleanup（不打断工作）
- 窗口锚定在屏幕顶部中央（notch 附近）

### 状态检测
- 基于 `normalized transcript tail` 的 signal scoring 判断 session 状态
- 支持状态：`running` / `waitingInput` / `replyAvailable` / `completed` / `alert` / `failed`
- **Terminal.app/iTerm2 隐私保护**：transcript 为空时（无法读取内容），自动判定为 completed
- waitingInput vs completed 优先级：completed strong signal 优先，但 "Anything else?" 保持为 waitingInput

### 声音反馈
- transition-based chiptune 音效：taskStarted / waitingForReply / completed / failed
- 状态不变时不重复播放
- 声音开关：hoverExpand 面板右上角可切换 mute

### Auto Refresh
- 固定 1s 刷新间隔
- single-flight 保护避免并发刷新

### Reply Bridge
- 已接入真实 AppleScript 发送回复到 Claude Code
- 支持 Terminal.app 和 iTerm2

### Terminal Jump
- 点击 session 行跳转对应 Terminal/iTerm tab

---

## 三、技术架构

### 关键文件
- `MacIrlandApp/App/IslandCoordinator.swift` — island 窗口管理 + 状态切换
- `MacIrlandKit/Services/Observation/ObservationService.swift` — AppleScript 读取 + 状态判断
- `MacIrlandKit/Adapters/BuiltIn/BuiltInCLIAdapter.swift` — session 构建 + 状态映射
- `MacIrlandKit/Core/State/TaskStateStore.swift` — 全局状态管理 + transition 播放
- `MacIrlandKit/Services/Feedback/FeedbackService.swift` — 声音播放

### Signal Scoring 系统
- `ClaudeStatusJudge.judge(transcript:)` 是核心判断函数
- strong / medium / weak signals 加权计分
- anti-signals 负分压制误判
- `qualifies()` 门槛：strong signal 或 total >= 3 或 (medium signal + matchedSignals >= 2)

---

## 四、已知限制

1. **transcript 仍是启发式识别**，不是强 session API（依赖窗口标题/进程名匹配）
2. **Apple Events 自动化权限**需用户手动在系统设置中授权
3. **Codex / Gemini** 非完整真实链路，仅观测层接入
4. **reply 草稿**仅保存在 app 运行期，不持久化
5. **dev 启动**依赖本地 `.app` 脚本，不等于正式发行形态

---

## 五、最近修复（2026-04-11）

| Bug | 修复内容 |
|-----|---------|
| Hover expand 闪烁 | `recomputeMode()` 不再重建 NSTrackingArea，避免合成鼠标事件 |
| 点击 island 弹出 panel | `openPanel()` 已禁用，只做本地 cleanup |
| 任务完成后仍显示 running | Terminal.app/iTerm2 transcript 为空时，自动判定 completed |
| 声音误播 | waitingInput anti-signals 减少误判；completed strong signal 优先 |

---

## 六、测试覆盖

- `TaskStateStoreTests` — 状态转换、transition 播放、session 合并
- `ReplyBridgeServiceTests` — AppleScript reply 发送
- `AppLaunchSupportTests` — 启动模式检测、Info.plist 验证
- `UIDisplayFormattingTests` — UI 文案格式化

**214 tests, all passing**

---

## 七、下一步探索方向

1. **更强的状态检测**：是否引入进程列表轮询作为补充信号？
2. **hoverExpand 交互扩展**：是否支持在 hoverExpand 中直接回复？
3. **多会话并发**：attention 优先级在极端情况（5+ 会话）下的表现
4. **持久化**：reply 草稿是否需要持久化存储？
5. **Codex/Gemini 真实链路**：是否有商业价值？
