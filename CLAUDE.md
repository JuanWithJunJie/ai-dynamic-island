# MacIrland

## 语言
回复给用户的反馈或结果要以中文形式呈现。

## 项目定位
一个 macOS AI CLI 会话观察器。

当前产品形态：
- 顶部 `island-first` 状态层
- 二级 `panel` 详情层
- `menu bar` 与 `Dock` 作为 fallback

当前真实链路主要围绕：
- `Claude Code + Terminal/iTerm`

## 当前状态
- island 已有 `compact + hoverExpand + highlighted` 三态
- hover expand：鼠标悬停展开显示当前 session 详情 + 所有 session 列表，点击行跳转 Terminal tab
- hover expand 稳定性：不在 `recomputeMode()` 中重建 tracking area，避免闪烁
- panel 点击已禁用：island 点击只做本地 cleanup，不再弹出 panel
- 应用级固定 `1s` 自动刷新（single-flight 保护）
- 真实 observation / reply bridge 已接入 Claude Code
- Claude 状态判断基于 normalized transcript tail；Terminal.app/iTerm2 transcript 为空时（隐私保护），自动判定为 completed
- diagnostics 同时展示 raw preview 和 normalized preview
- 统一图标状态系统：idle（绿色闪烁）/ running（绿色动画点）/ completed（橙色静态）
- 真实 chiptune 声音反馈（完成/失败/开始/等待），hover expand 面板右上角可开关
- alert 状态保持可见但不自动大展开
- Codex / Gemini 仍非完整真实链路

## 关键文件

### App
- `MacIrlandApp/App/AppDelegate.swift`
- `MacIrlandApp/App/IslandCoordinator.swift`
- `MacIrlandApp/App/PanelCoordinator.swift`
- `MacIrlandApp/App/RefreshCoordinator.swift`
- `MacIrlandApp/App/StatusBarController.swift`
- `MacIrlandApp/App/LaunchSupport.swift`

### Core
- `MacIrlandKit/Core/State/TaskStateStore.swift`
- `MacIrlandKit/Services/SessionRecognition/SessionResolver.swift`
- `MacIrlandKit/Services/Observation/ObservationService.swift`
- `MacIrlandKit/Adapters/BuiltIn/BuiltInCLIAdapter.swift`
- `MacIrlandKit/Core/Models/TaskModels.swift`

### UI
- `MacIrlandKit/Features/Island/IslandPresentation.swift`
- `MacIrlandKit/Features/Island/IslandStatusStripView.swift`
- `MacIrlandKit/Features/Island/IslandExpandedCardView.swift`
- `MacIrlandKit/Features/Island/IslandSurfaceView.swift`
- `MacIrlandKit/Features/Island/IslandMultiSessionTrayView.swift`
- `MacIrlandKit/Features/Island/IslandHoverExpandView.swift`
- `MacIrlandKit/Features/Icon/AnimatedStatusIcon.swift`
- `MacIrlandKit/Features/Panel/PanelView.swift`
- `MacIrlandKit/Features/Panel/SessionDetailView.swift`
- `MacIrlandKit/Features/Panel/SessionPickerView.swift`
- `MacIrlandKit/Features/Diagnostics/DiagnosticsSectionView.swift`

### Feedback / Terminal
- `MacIrlandKit/Services/Feedback/ChiptuneSoundPlayer.swift`
- `MacIrlandKit/Services/Feedback/FeedbackService.swift`
- `MacIrlandKit/Services/TerminalJump/TerminalJumpService.swift`
- `MacIrlandKit/Services/Persistence/LocalStore.swift`

### Tests
- `MacIrlandTests/TaskStateStoreTests.swift`
- `MacIrlandTests/AppLaunchSupportTests.swift`
- `MacIrlandTests/UIDisplayFormattingTests.swift`
- `MacIrlandTests/ReplyBridgeServiceTests.swift`

## 启动与验证

启动：
```bash
cd /Users/lijunjie/Documents/AIproject/macirland
./Scripts/run-dev-app.sh
```

验证：
```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland"
swift build --package-path "/Users/lijunjie/Documents/AIproject/macirland"
```

## 当前限制
- transcript / observation 仍是启发式识别，不是强 session API
- Apple Events / 自动化权限仍需用户手动允许
- menu bar 位置由 macOS 决定，所以只算 fallback
- reply 草稿仅保存在当前 app 运行期
- dev 启动依赖本地 `.app` 脚本，不等于正式发行形态

## 高风险点
- `1s` 自动刷新相关改动要小心：
  - 不要重新引入 duplicate `TaskSession.id`
  - 不要破坏 attention session 选择语义
  - 不要用降低刷新频率代替修复
- 如果改 island 行为，要同时留意：
  - `preferredIslandSession`
  - `islandAttentionSessions`
  - panel handoff 是否仍指向正确 session

## 图标状态语义
统一的状态图标系统，应用于 compact island、highlighted card、tray rows、menu bar：
- `idle`: 终端图标 + 绿色透明度交替闪烁（0.8s 周期），表示无活跃 session
- `running`: 终端图标 + 4个动画点逐步亮起（0.18s 周期），绿色，表示运行中
- `waiting`: 橙色省略号圆圈 + 脉冲动画（0.6s 周期），表示等待用户下一步/回复
- `completed`: 橙色对勾圆圈，静止，表示任务完成

Island compact 状态图标使用 `preferredIslandSession`（优先级最高的 session）的状态，确保图标与 statusText 一致。

颜色语义：
- `.running` → 绿色
- `.completed` → 橙色
- `.waitingInput`/`.replyAvailable` → 橙色（`.waiting` 状态）
- `.alert`/`.failed` → 红色

Island hover expand（Option B）交互：
- 多 session 时 hover 触发 `.hoverExpand` 模式（替代旧的 `.tray` 模式）
- hover expand 布局：上半部分显示 `preferredIslandSession` 详情，下半部分显示 `traySessions` 列表
- 点击 session 行 → `TerminalJumpService.jump()` 激活对应 Terminal tab（不关闭 island）
- 鼠标离开 200ms 延迟后自动折叠回 `.compact`
- 声音开关按钮位于 status strip 右侧，hover 时淡入/淡出

Tray 触发条件：
- `hasMultipleRelevantSessions` 基于 `traySessions.count > 1`
- `traySessions` 是单一数据源，过滤掉 terminal 状态会话
- 只在有多个真正活跃的相关会话时触发 hover expand
- List header 和 rows 都使用 `traySessions`（同一数据源）

Panel 主 surface Claude-first：
- `primaryPanelSessions` 是 panel 主导航的单一数据源，过滤掉 terminal 状态会话
- `selectedSession` 优先返回当前选中的 session（如果在 `primaryPanelSessions` 中），否则回退到 `primaryPanelSessions.first`
- `SessionPickerView` 使用 `primaryPanelSessions` 而非全量 `sessions`
- 非 Claude 会话不在主产品层与 Claude 会话同等竞争，但仍可通过 diagnostics 观察

状态跃迁识别（ClaudeStatusJudge）：
- `ClaudeStatusJudge.judge(transcript:)` 使用 signal scoring 识别真实 Claude transcript 结束模式
- 识别 3 类 post-run 状态：`waitingInput`（等待用户指示）、`replyAvailable`（等待用户回复）、`completed`（任务完成）
- 关键 end-of-turn 信号：
  - `waitingInput` strong: "what's next", "your turn", "let me know if", "tell me if you want", "anything else", "what else", "还需要什么", "还有什么需要"
  - `replyAvailable` strong: "if you want", "feel free to ask", "if you'd like", "if you need"
  - `completed` strong: "i'm done", "all done", "all set", "done!", "that's all for now", "you're all set", "created file:", "created directory:"
- `qualifies()` 要求：strong signal 或 total >= 3 或 (medium signal + matchedSignals >= 2)
- Terminal.app/iTerm2 transcript 为空时（隐私保护）：snippet 含 "Running ... terminal session:" 且 transcript 空 → 判 completed
- `BuiltInCLIAdapter.status(for:)` 与 `ClaudeStatusJudge` 保持对齐

声音提示语义（transition-based）：
- `.taskStarted`: 仅在 session 首次进入 running 时播放一次
- `.waitingForReply`: 仅在 session 首次进入 waitingInput/replyAvailable 时播放一次
- `.completed`: 仅在 session 首次进入 completed 时播放一次
- `.failed`: 仅在 session 首次进入 alert/failed 时播放一次
- 状态保持不变时不会重复播放
- 声音开关：hover expand 面板右上角，点击切换 `.all`（开）和 `.mute`（关）
- `TaskStateStore.soundMode` 通过 `UserDefaultsLocalStore` 持久化

Alert 轻提示语义：
- alert 在 compact 状态显示红色边框和"点击查看详情"副文本
- alert 在 tray row 中显示红色背景高亮（12% 透明度）
- alert 不会自动大展开打断工作

Readiness / Onboarding：
- `appReadiness` 是统一的产品层 readiness 模型，由 `TaskStateStore` 计算
- 5 种状态：`.ready`、`.blocked`、`.noSession`、`.limitedReply`、`.partialObservation`
- blocked 状态在 EmptyWorkspaceView 中显示橙色标题 + 引导文字 + "打开系统设置"按钮
- noSession 状态显示"还没有 Claude Code 会话"并提示下一步
- 状态用于 primary panel surface，不在 diagnostics 中
- diagnostics 继续作为低优先级工程观察层

## 必看文档
- 自动刷新 crash 修复：`docs/superpowers/plans/2026-04-10-auto-refresh-crash-fix-implementation.md`
- 自动刷新回归修复：`docs/superpowers/plans/2026-04-10-auto-refresh-crash-regression-fix-implementation.md`
- Hover expand + sound toggle 实现：`docs/superpowers/plans/2026-04-11-island-hover-expand-option-b-implementation.md`
- GitHub 推送说明：`docs/guides/github-ssh-push.md`

## GitHub 备注
- 这台机器访问 GitHub 依赖本地代理
- 如 `git` / `gh` 连不上，先：
```bash
source ~/.zshrc
git ls-remote origin HEAD
gh auth status
curl -I https://api.github.com
```

## gstack
- 所有网页浏览优先使用 gstack 的 `/browse`
- 不要使用 `mcp__claude-in-chrome__*` 工具
- 可用技能：
  - `/office-hours`
  - `/plan-ceo-review`
  - `/plan-eng-review`
  - `/plan-design-review`
  - `/design-consultation`
  - `/design-shotgun`
  - `/design-html`
  - `/review`
  - `/ship`
  - `/land-and-deploy`
  - `/canary`
  - `/benchmark`
  - `/browse`
  - `/connect-chrome`
  - `/qa`
  - `/qa-only`
  - `/design-review`
  - `/setup-browser-cookies`
  - `/setup-deploy`
  - `/retro`
  - `/investigate`
  - `/document-release`
  - `/codex`
  - `/cso`
  - `/autoplan`
  - `/careful`
  - `/freeze`
  - `/guard`
  - `/unfreeze`
  - `/gstack-upgrade`
  - `/learn`
- 如果 gstack 技能不可用，先运行：
```bash
cd ~/.claude/skills/gstack && ./setup
```
