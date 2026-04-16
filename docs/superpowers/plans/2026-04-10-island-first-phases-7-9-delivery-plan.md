# Island-First Phases 7-9 Delivery Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan strictly phase-by-phase. Do not merge tasks across phases. Each phase must end with its own execution report markdown file.

**Goal:** 完成 MacIrland 的 island-first 收尾阶段，让产品从“形态已成立”推进到“多会话行为稳定、回复链路可信、整体可演示且接近真实可用”。

**Architecture:** 现阶段不再大改外形，重点转向三个层面：多会话 attention queue、真实 reply bridge 硬化、以及最终的产品稳定性收口。执行时必须按 `Phase 7 -> Phase 8 -> Phase 9` 严格串行推进，前一阶段验证完成后才能进入后一阶段。

**Tech Stack:** SwiftUI, AppKit `NSPanel`, `TaskStateStore`, `IslandCoordinator`, `PanelCoordinator`, `ReplyBridgeService`, AppleScript terminal automation, XCTest

---

## Baseline

执行本计划前，仓库应已具备这些能力：
- compact island / status strip
- expanded single-task card
- 1 个推荐 quick action
- 轻量动效 + auto-collapse
- panel 作为二级详情层
- 多 session arbitration
- island -> panel handoff 与当前焦点对齐

当前系统已知事实：
- `ReplyBridgeService` 已存在，并支持通过 AppleScript 向 `Claude Code + Terminal/iTerm` 写回消息
- 但这条链路还没有被当作“第一层产品能力”做稳定性、验证和 UX 收口
- 当前最关键的剩余工作是：
  - 多 session 的 queue handoff
  - reply writeback 的产品化硬化
  - 最终边界行为、文案与稳定性收尾

---

## Global Execution Rules

- 必须严格按 `Phase 7 -> Phase 8 -> Phase 9` 顺序执行
- 每个 phase 内也必须按 task 顺序执行
- 一次只做一个 task
- 每完成一个 task，先运行该 task 的验证命令
- 只有当前 phase 的 task 级验证和全量验证都通过，才能开始下一个 phase
- 如果某个 phase 中途阻塞，必须停在该 phase，不允许继续实现后续 phase
- 不要回退任何已有用户改动
- 不要自行扩展到计划之外的产品功能

统一不做的事情：
- 不重写 observation / adapter / session matching
- 不新增复杂动画、hover 专属行为或复杂手势
- 不把 panel 再抬回第一层工作台
- 不新增多按钮密集交互
- 不同时把 Codex / Gemini 全量真实写回一起做了

---

## Phase 7 — Attention Queue / Interruption Handoff

### Goal
让 island 从“知道当前该高亮谁”升级成“知道当前项结束后，下一个待处理项如何接力”。

### In Scope
- 建立 island attention queue helper
- dismiss 当前 highlighted 后，优先切到下一个 attention session
- `.alert` / `.replyAvailable` 自动收回后，如仍有 attention queue，继续 handoff
- compact / highlighted 加轻量 pending cue，告诉用户后面还有待处理项

### Out of Scope
- 真实 reply bridge 扩展
- 多 quick action
- 自由输入直达 island
- 新动画类型

### Files
- Modify: `MacIrlandKit/Core/State/TaskStateStore.swift`
- Modify: `MacIrlandKit/Features/Island/IslandPresentation.swift`
- Modify: `MacIrlandKit/Features/Island/IslandStatusStripView.swift`
- Modify: `MacIrlandKit/Features/Island/IslandExpandedCardView.swift`
- Modify: `MacIrlandApp/App/IslandCoordinator.swift`
- Modify: `MacIrlandTests/TaskStateStoreTests.swift`
- Modify: `MacIrlandTests/UIDisplayFormattingTests.swift`
- Modify: `MacIrlandTests/AppLaunchSupportTests.swift`
- Modify: `CLAUDE.md`

### Required Outcomes
- `TaskStateStore` 能提供 island attention queue / secondary count
- dismiss 当前 highlighted 后，若后面还有 attention session，会切到下一项
- transient auto-collapse 后，若 attention queue 未空，不直接回 compact
- compact / highlighted 均可轻量表达“后面还有待处理项”

### Verification
```bash
swift test --filter TaskStateStoreTests
swift test --filter UIDisplayFormattingTests
swift test --filter AppLaunchSupportTests
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland"
swift build --package-path "/Users/lijunjie/Documents/AIproject/macirland"
```

### Phase 7 Exit Gate
- attention queue handoff 行为通过测试
- `CLAUDE.md` 已更新
- execution report 已写入：

---

## Phase 8 — Reply Bridge Hardening / Intervention Reliability

### Goal
把当前已存在的 `ReplyBridgeService` 从“底层能力已存在”推进成“可被产品信任的真实介入路径”。

### Important Baseline For This Phase
- 当前 `ReplyBridgeService` 已支持：
  - `Claude Code`
  - `Terminal`
  - `iTerm`
- 当前 Phase 8 **不是** 从零发明 reply bridge
- 当前 Phase 8 的目标是：**把现有真实桥接链路做稳定性、验证、错误反馈和 UI 收口**

### In Scope
- 统一 panel quick action / panel free text / island quick action 的真实写回语义
- 强化 `ReplyBridgeService.validateReply` / `sendReply` 的失败说明与目标一致性
- 让 UI 更明确表达“当前是否真的可发送”
- 保持 runtime history 继续记录成功发送 / 拒绝发送
- 补独立的 reply bridge 测试

### Out of Scope
- Codex / Gemini 真实写回
- 新的 bridge transport
- 长连接守护进程
- 大规模 permission system 重写

### Files
- Modify: `MacIrlandKit/Services/ReplyBridge/ReplyBridgeService.swift`
- Modify: `MacIrlandKit/Core/State/TaskStateStore.swift`
- Modify: `MacIrlandKit/Features/Island/IslandPresentation.swift`
- Modify: `MacIrlandKit/Features/Island/IslandExpandedCardView.swift`
- Modify: `MacIrlandKit/Features/Panel/SessionDetailView.swift`
- Modify: `MacIrlandKit/Features/Panel/PanelView.swift`
- Modify: `MacIrlandTests/TaskStateStoreTests.swift`
- Modify: `MacIrlandTests/UIDisplayFormattingTests.swift`
- Modify: `MacIrlandTests/AppLaunchSupportTests.swift`
- Create: `MacIrlandTests/ReplyBridgeServiceTests.swift`
- Modify: `CLAUDE.md`

### Required Outcomes
- island quick action、panel quick action、panel 自由输入都复用同一套真实桥接判断
- UI 能在发送前表达“可发送 / 不可发送 / 需要刷新 / 权限缺失”
- 错误说明保持可操作，不要只返回泛化失败
- 仅保留 `Claude Code + Terminal/iTerm` 作为第一条真实闭环，不扩到其他 CLI

### Verification
```bash
swift test --filter ReplyBridgeServiceTests
swift test --filter TaskStateStoreTests
swift test --filter UIDisplayFormattingTests
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland"
swift build --package-path "/Users/lijunjie/Documents/AIproject/macirland"
```

### Phase 8 Exit Gate
- 至少一条真实 reply bridge 路径被明确验证可用
- panel / island 的发送前后反馈一致
- `CLAUDE.md` 已更新
- execution report 已写入：

---

## Phase 9 — Product Polish / Stability Closure

### Goal
在行为与能力闭环之后，完成最后一轮产品收口，让 island-first 进入稳定基线。

### In Scope
- 统一 compact / highlighted / panel 的状态词和 copy
- 梳理主要边界行为矩阵：
  - 无 session
  - 单 session
  - 多 session 同 tier
  - 高 tier 抢占
  - dismiss 后接力
  - auto-collapse 后接力
  - reply 成功 / reply 失败
- 收口轻量视觉细节和 secondary cue
- 完成最终回归验证与文档更新

### Out of Scope
- 新产品形态
- 更复杂的交互模式
- 进一步架构重写

### Files
- Modify: `MacIrlandKit/Features/Island/IslandPresentation.swift`
- Modify: `MacIrlandKit/Features/Island/IslandStatusStripView.swift`
- Modify: `MacIrlandKit/Features/Island/IslandExpandedCardView.swift`
- Modify: `MacIrlandKit/Features/Panel/PanelView.swift`
- Modify: `MacIrlandKit/Features/Panel/SessionDetailView.swift`
- Modify: `MacIrlandKit/Features/Panel/SessionPickerView.swift`
- Modify: `MacIrlandTests/TaskStateStoreTests.swift`
- Modify: `MacIrlandTests/UIDisplayFormattingTests.swift`
- Modify: `MacIrlandTests/AppLaunchSupportTests.swift`
- Modify: `CLAUDE.md`

### Required Outcomes
- 状态词、边界提示、发送反馈在三层 UI 中保持一致
- 主要边界行为都有测试覆盖
- 轻量 cue 不噪音、不回退成 panel-first
- 项目达到“可稳定演示，且至少一条真实介入链路可用”

### Verification
```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland"
swift build --package-path "/Users/lijunjie/Documents/AIproject/macirland"
```

### Phase 9 Exit Gate
- 全量测试通过
- build 通过
- `CLAUDE.md` 已更新
- execution report 已写入：

---

## Definition of Done

当下面这些都满足时，可以认为 island-first 第一阶段基本做完：

- island 在多 session 场景下不会乱跳
- 当前高亮项结束后，后续 attention session 会自然接上
- 至少一条真实 reply bridge 路径可用
- island 与 panel 的焦点一致
- 主要边界行为有测试覆盖
- `swift test` / `swift build` 通过
- `CLAUDE.md` 和三份 phase execution report 都已落盘

---

## Final Reporting Requirements

执行完整个 7-9 计划后，最终汇报必须包含：
- 实际修改的文件列表
- Phase 7 / 8 / 9 各自的完成情况
- 各 phase 的 task 级测试命令
- 最终全量验证命令
- 是否更新了 `CLAUDE.md`
- 3 份 execution report 的绝对路径
- 任一 phase 是否偏离计划；如果有，逐条说明原因

---

## Sequencing Reminder

最重要的一条规则：

**不要把这 3 个 phase 混着做。**

正确方式只有一种：

1. 完成 Phase 7，并验证通过
2. 完成 Phase 8，并验证通过
3. 完成 Phase 9，并验证通过

如果中途卡住，停在当前 phase，不要提前实现下一 phase。
