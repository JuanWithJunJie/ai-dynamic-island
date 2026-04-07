# MacIrland

## 项目是什么
一个 macOS 菜单栏 + 浮动面板应用，用来统一观察 AI CLI 会话（Claude Code / Codex / Gemini）的任务状态、提醒与回复入口。

## 当前结构
- `MacIrlandKit`：核心模型、状态管理、服务、SwiftUI 视图、mock 数据
- `MacIrlandApp`：App 启动、状态栏按钮、面板协调、设置页
- `MacIrlandTests`：单元测试

## 当前进展
- 已有菜单栏入口和浮动面板
- 已有任务模型、状态枚举、摘要聚合、基础诊断视图
- 面板已支持多 session 列表 + 选中详情
- 已补上选中 session 状态，并让 session 在 refresh 时可稳定匹配
- 已接入真实 observation：通过 AppleScript 从 Terminal / iTerm 发现 Claude Code 会话
- 已把 Claude Code 的真实状态识别推进到更可用：可区分 running / waiting input / completed / alert / failed / contextLost
- Claude Code 状态判定已从纯关键词命中升级为轻量多信号判定，并在 real observation / adapter 两条路径复用同一套 judgement
- 已补上本地 dev `.app` 启动路径：不再只依赖 `swift run`，可通过脚本打包并启动菜单栏 app 形态
- dev 启动脚本现在会在重启前显式结束旧的 `MacIrland` 进程，避免 macOS 复用旧实例导致“以为已经更新，实际还是旧 UI / 旧逻辑”的假象
- 菜单栏入口已改成 SwiftUI `MenuBarExtra` 生命周期承载，不再只依赖 AppDelegate 里手工创建 `NSStatusItem`
- 已按 `docs/superpowers/plans/2026-04-06-ui-reference-alignment.md` 落下第一刀 UI 对齐：菜单栏入口改为更接近参考图 1 的紧凑胶囊状态块，主浮动面板改成接近参考图 2 的深色悬浮壳
- 已在第一刀基础上继续做收敛：菜单栏胶囊进一步减重减宽，panel 层级从“多张同权重卡片堆叠”收回到更清晰的主次结构
- 已根据实际体验反馈再次回调菜单栏入口可见性：恢复更明确的终端 icon 和更实一点的对比度，避免胶囊太透明、太难定位
- 已进一步放弃过度极简的菜单栏胶囊方案，改回更接近原生菜单栏入口的宽标签：icon + MI + 状态数字，优先保证在刘海屏旁边更容易被看到
- 已新增一层轻量设计系统：深色背景、表面层级、卡片容器、chip/tag 组件和展示格式 helper，避免样式散落在各个 view 里硬写
- session 列表已从偏工程化列表推进到 feed/card 风格，详情区也已拆成更清晰的摘要卡、事件卡、消息卡和回复卡
- 已继续推进第二刀：详情区加入主操作提示和 activity timeline，展开态更接近参考图 2 的工作台 / feed 感
- 已新增启动方式识别：如果直接运行可执行文件而不是 `.app`，应用会弹窗提示改用 `./Scripts/run-dev-app.sh`，并在提示后退出，避免出现“进程在跑但菜单栏没有入口”的误判
- 已开始回到真实 observation 稳定性：Claude Code 识别不再只依赖非常窄的 `claude` 命中，还能兼容更真实的 Terminal / iTerm 命令元数据；当终端在运行但本轮读不到会话时，panel 空态也会明确提示可能是自动化权限或读取失败
- 已进一步把“猜不到为什么没识别到”变成“直接看本轮 observation 读到了什么”：diagnostics 区现在会展示 Terminal / iTerm reader 结果、raw session 元数据，以及 observation 被识别或丢弃的原因
- 已继续收尾 Claude Code 真实发现稳定性：一次 refresh 现在会消费同一份 observation snapshot，避免 session 列表和 diagnostics 来自两轮不同抓取；AppleScript reader 也会保留更具体的错误说明，方便判断是权限问题还是读取失败
- 已修复 dev `.app` 的 Apple Events 身份稳定性：补上 `NSAppleEventsUsageDescription`，并让打包脚本用稳定的 `com.macirland.app` 对 `.app` 重新签名，避免系统把每次构建都当成不同的自动化主体
- 已补上 Claude 会话识别的 transcript fallback：当 iTerm / Terminal 的 `windowTitle` 或 `commandLine` 不可靠时，也能从 Claude Code header 预览里识别会话，避免 `raw > 0` 但 `recognized = 0`
- 真实 observation 当前仍只覆盖 Claude Code；Codex / Gemini 仍主要依赖 mock
- Reply bridge 仍是 mock，不是真实回写 CLI
- 当前 `swift test` 和 `swift build` 已通过

## 当前限制
- 真实状态识别仍主要基于终端 transcript 启发式；虽然已改成多信号判定，但复杂长文本场景下仍可能误判
- 如果系统未授权 Apple Events / 自动化权限，真实 observation 结果会为空
- Reply bridge 还是 mock，不是真实回写 CLI
- `draftReply` 仍是全局草稿，不是每个 session 各自独立
- 本地运行菜单栏体验当前依赖新加的 dev app 启动脚本，不是完整发行形态
- 目前对“错误启动方式”的处理是弹窗提示并退出，不会尝试兼容裸可执行文件直跑
- 菜单栏入口位置仍由 macOS 决定；本轮只能通过更紧凑的胶囊 label 降低被刘海/拥挤状态栏遮挡的概率，不能精确控制位置
- 当前 UI 已明显朝参考图靠拢，但还没有做复杂动画、真实 reply bridge、或更深的 session 时间线设计
- 当前 timeline 仍是基于现有 `recentEvents` / `recentMessages` 的轻量合成，不是完整多步执行历史
- macOS 自动化权限仍需要用户在系统弹窗或“隐私与安全性 -> 自动化”中手动允许，应用无法静默代授
- transcript fallback 目前仍是保守启发式，需要至少命中 `Claude Code v` 这类头部信号和额外上下文信号，避免普通文本误判

## 先看这些文件
- `MacIrlandKit/Services/Observation/ObservationService.swift`
- `MacIrlandKit/Services/Permissions/PermissionService.swift`
- `MacIrlandApp/App/AppDelegate.swift`
- `MacIrlandApp/App/LaunchSupport.swift`
- `MacIrlandApp/App/MacIrlandApp.swift`
- `MacIrlandApp/App/MenuBarStatusLabel.swift`
- `MacIrlandApp/App/PanelCoordinator.swift`
- `MacIrlandKit/Core/State/TaskStateStore.swift`
- `MacIrlandKit/Adapters/BuiltIn/BuiltInCLIAdapter.swift`
- `MacIrlandKit/DesignSystem/PanelTheme.swift`
- `MacIrlandKit/DesignSystem/DisplayFormatting.swift`
- `MacIrlandKit/Features/Panel/PanelView.swift`
- `MacIrlandKit/Features/Panel/SessionPickerView.swift`
- `MacIrlandKit/Features/Panel/SessionDetailView.swift`
- `MacIrlandKit/Features/Diagnostics/DiagnosticsSectionView.swift`
- `MacIrlandTests/TaskStateStoreTests.swift`
- `MacIrlandTests/AppLaunchSupportTests.swift`
- `MacIrlandTests/UIDisplayFormattingTests.swift`

## 本次修改（2026-04-06）
- 修改 1：新增 `MacIrlandApp/App/LaunchSupport.swift`，集中处理启动方式识别和错误启动提示文案。
- 修改 2：更新 `MacIrlandApp/App/AppDelegate.swift`，在检测到不是 `.app` 形态启动时弹窗提示用户运行 `./Scripts/run-dev-app.sh`，提示后直接退出。
- 修改 3：新增 `MacIrlandApp/App/MenuBarStatusLabel.swift`，把菜单栏入口改成更接近参考图 1 的紧凑胶囊状态块：左侧品牌像素标识，右侧数字状态胶囊。
- 修改 4：更新 `Package.swift` 与 `MacIrlandTests/AppLaunchSupportTests.swift`，为启动方式识别补了单元测试。
- 修改 5：新增 `docs/superpowers/plans/2026-04-06-menu-bar-visibility.md`，记录这次修复的实现计划。
- 修改 6：新增 `MacIrlandKit/DesignSystem/PanelTheme.swift` 与 `MacIrlandKit/DesignSystem/DisplayFormatting.swift`，补了一层 UI token、卡片容器、chip/tag 组件和展示 helper。
- 修改 7：更新 `MacIrlandApp/App/PanelCoordinator.swift` 与 `MacIrlandKit/Features/Panel/PanelView.swift`，把面板外层改成更接近参考图 2 的深色悬浮容器、品牌 header 和卡片化结构。
- 修改 8：更新 `MacIrlandKit/Features/Island/IslandCompactView.swift`、`MacIrlandKit/Features/Overview/OverviewSectionView.swift`、`MacIrlandKit/Features/Panel/SessionPickerView.swift`、`MacIrlandKit/Features/Panel/SessionDetailView.swift`、`MacIrlandKit/Features/Diagnostics/DiagnosticsSectionView.swift`，把 session feed、详情区和诊断区统一到新的视觉语言。
- 修改 9：新增 `MacIrlandTests/UIDisplayFormattingTests.swift`，覆盖终端来源展示、汇总计数和菜单栏状态表达。
- 修改 10：更新 `MacIrlandKit/DesignSystem/DisplayFormatting.swift` 与 `MacIrlandKit/Features/Panel/SessionDetailView.swift`，为详情区补了主操作提示、事件/消息合并时间线和 timeline row 呈现。
- 修改 11：更新 `MacIrlandApp/App/MenuBarStatusLabel.swift`、`MacIrlandKit/Features/Panel/PanelView.swift`、`MacIrlandKit/Features/Panel/SessionDetailView.swift`、`MacIrlandKit/Features/Overview/OverviewSectionView.swift`、`MacIrlandKit/Features/Diagnostics/DiagnosticsSectionView.swift`，把第一版参考图对齐结果再做一轮收敛：缩窄菜单栏胶囊、减轻双层 capsule 感，并降低 panel 内部同权重 / 嵌套卡片感。
- 修改 12：再次更新 `MacIrlandApp/App/MenuBarStatusLabel.swift`，把菜单栏入口从过轻过透明的极简胶囊回调到“可一眼识别”的版本：恢复明确 terminal icon、提高对比度，并保留状态数字。
- 修改 13：继续更新 `MacIrlandApp/App/MenuBarStatusLabel.swift`，进一步把菜单栏入口改成更宽、更接近原生菜单栏可见性的标签：`terminal icon + MI + count`，不再优先追求极小胶囊。
- 修改 14：更新 `MacIrlandKit/Services/Observation/ObservationService.swift` 与 `MacIrlandKit/Adapters/BuiltIn/BuiltInCLIAdapter.swift`，把 Claude Code 实时识别统一到一套更宽但仍保守的 matcher，上移对真实 Terminal / iTerm 命令元数据的兼容。
- 修改 15：更新 `MacIrlandKit/Core/Models/TaskModels.swift`、`MacIrlandKit/Services/Permissions/PermissionService.swift`、`MacIrlandKit/Core/State/TaskStateStore.swift`、`MacIrlandKit/Features/Panel/SessionPickerView.swift`、`MacIrlandKit/Features/Diagnostics/DiagnosticsSectionView.swift`，让“没有会话”和“终端在运行但本轮无法读取会话”这两种空态在 panel 中有不同提示。
- 修改 16：更新 `MacIrlandTests/TaskStateStoreTests.swift`，补上更真实的 Claude 终端元数据识别用例，以及 observation blocked 空态回归测试。
- 修改 17：更新 `MacIrlandKit/Core/Models/TaskModels.swift`、`MacIrlandKit/Services/Observation/ObservationService.swift`、`MacIrlandKit/Core/State/TaskStateStore.swift`、`MacIrlandKit/Features/Panel/PanelView.swift`、`MacIrlandKit/Features/Diagnostics/DiagnosticsSectionView.swift`、`MacIrlandTests/TaskStateStoreTests.swift`，新增原始 observation diagnostics：reader 读取结果、raw session 元数据、识别结果与丢弃原因都会保留并显示在 diagnostics 区。
- 修改 18：继续更新 `MacIrlandKit/Services/Observation/ObservationService.swift`、`MacIrlandKit/Core/State/TaskStateStore.swift`、`MacIrlandKit/Features/Panel/PanelView.swift`、`MacIrlandTests/TaskStateStoreTests.swift`，把 observation 改成单次 snapshot 驱动，避免 events / diagnostics 漂移；同时把 AppleScript reader 错误说明上抬到 reader diagnostics 和空态引导里。
- 修改 18：更新 `Scripts/run-dev-app.sh`，在重新打开 dev `.app` 之前显式结束旧的 `MacIrland` 进程，避免 macOS 直接复用旧实例。
- 修改 19：更新 `MacIrlandApp/Resources/Info.plist` 与 `Scripts/run-dev-app.sh`，补上 `NSAppleEventsUsageDescription`，并在 dev `.app` 打包后使用稳定的 `com.macirland.app` 重新签名；同时重置 `AppleEvents` 授权状态以便系统重新弹出 Terminal / iTerm 自动化授权。
- 修改 20：更新 `MacIrlandKit/Services/Observation/ObservationService.swift`、`MacIrlandKit/Adapters/BuiltIn/BuiltInCLIAdapter.swift`、`MacIrlandTests/TaskStateStoreTests.swift`，让 observation 可以从 transcript header 兜底识别 Claude Code，并保证已识别出来的事件在 adapter/buildSession 阶段不会被再次错误丢弃。

## 本次结果（2026-04-06）
- 结果 1：用户如果用错启动方式，不会再陷入“项目已经运行但菜单栏找不到”的静默失败状态，而是会收到明确提示。
- 结果 2：用户即使用对启动方式，在菜单栏里也更容易识别该应用入口；入口现在是更接近参考图 1 的胶囊状态块，而不只是普通图标或文字。
- 结果 3：主浮动面板已从“开发中工具面板”明显推进到“深色悬浮工作台”风格，顶部品牌区、卡片容器、chips/tag 和 feed 式 session row 都已落下第一版。
- 结果 4：本轮运行态验证已确认：`./Scripts/run-dev-app.sh` 可启动 `.app`，菜单栏项可点击，浮动面板仍可正常展开。
- 结果 5：详情区已不再只是静态分组块，而是会根据状态给出更明确的当前操作提示，并把最近事件和消息按时间倒序合成为统一 timeline。
- 结果 6：在这一版基础上又进一步去掉了最重的“卡中卡”视觉问题：session detail 改成统一工作区，overview 与 diagnostics 也降成更轻的辅助层级。
- 结果 7：菜单栏入口在极简化后又根据实机体验做了可见性回调：现在比纯透明胶囊更容易被用户在顶部状态栏里快速发现。
- 结果 8：在刘海屏场景下，菜单栏入口已进一步改成更宽的 `icon + MI + count` 方案；这一轮优先解决“找不到入口”，而不是继续追求最小视觉体积。
- 结果 9：当前面板在 Claude Code 真实发现这条链路上不再只接受非常窄的命令字符串；Terminal / iTerm 返回更真实的进程/命令元数据时，也更有机会被识别成 Claude 会话。
- 结果 10：如果终端应用正在运行，但本轮 observation 没有成功读到任何会话，panel 不再只给出普通空态，而会明确提示用户检查 Apple Events / 自动化权限。
- 结果 11：diagnostics 区现在还能直接展示本轮 reader 结果、raw `windowTitle` / `commandLine` / `tty`，以及 observation 为何被识别或丢弃，便于继续做实机排障。
- 结果 12：同一轮 refresh 里的 session 列表与 diagnostics 已改成共享一份 observation snapshot，排除了“看到的诊断和列表不属于同一次抓取”的漂移问题。
- 结果 13：AppleScript reader 失败时，diagnostics 里会保留更具体的错误说明；任务列表空态也会在“读不到终端”与“读到了 raw session 但没命中 Claude 规则”之间做区分。
- 结果 14：dev 启动脚本现在会先结束旧实例再重开 `.app`，避免用户看到的是前一版进程，从而误判“新改动没有生效”。
- 结果 15：dev `.app` 当前的签名标识已经稳定为 `com.macirland.app`，系统现在能把 Apple Events / 自动化授权绑定到稳定主体，而不是每次构建生成新的 hash 标识。
- 结果 16：我已执行 `tccutil reset AppleEvents com.macirland.app`，旧的错误授权状态已经清掉；下一次 MacIrland 真实访问 Terminal / iTerm 时，系统会重新弹出授权。
- 结果 17：相关逻辑已有单元测试覆盖；本轮本地验证命令为 `swift test --filter AppLaunchSupportTests`、`swift test --filter UIDisplayFormattingTests`、`swift test`、`swift build`。
- 结果 18：现在像 “`command` 为空、`windowTitle` 很弱，但 transcript 里有 `Claude Code v2.x` / `Sonnet ... / API Usage Billing`” 这样的 iTerm 会话，也能被识别进 session 列表；对应防误判用例仍保持通过。

## 下一步建议
如果继续沿着 `2026-04-06-ui-reference-alignment.md` 往下推进，下一刀更值得做的是：把 timeline 从“最近消息 + 最近事件”扩成更完整的任务历史，并补上更强的视觉层次或细微动效；本轮先不做真实 reply bridge、不做 Codex/Gemini 全量真实接入。
