# Island-First Phases 8-9 Delivery Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan strictly phase-by-phase. Do not merge Phase 8 and Phase 9 tasks together. Finish Phase 8 completely before starting Phase 9.

**Goal:** 在 Phase 7 已完成 attention queue / interruption handoff 的基础上，完成 island-first 的最后两轮收尾，让 MacIrland 达到“可真实介入 + 可直接体验”的产品状态。

**Architecture:** 这两轮不再改变主形态，重点转向两个层面：先把现有 reply bridge 做成可信、可验证、可被 UI 正确表达的真实介入链路；再把 compact / highlighted / panel 三层体验的文案、边界行为和稳定性收口。执行时必须严格按 `Phase 8 -> Phase 9` 顺序推进。

**Tech Stack:** SwiftUI, AppKit `NSPanel`, `TaskStateStore`, `IslandCoordinator`, `PanelCoordinator`, `ReplyBridgeService`, AppleScript terminal automation, XCTest

---

## Baseline

执行本计划前，仓库应已具备：
- compact island / status strip
- expanded single-task card
- 1 个推荐 quick action
- 轻量动效 + auto-collapse
- panel 作为二级详情层
- island arbitration
- attention queue / interruption handoff
- island -> panel handoff 与当前焦点对齐

当前关键事实：
- `ReplyBridgeService` 已存在
- 当前已支持 `Claude Code + Terminal/iTerm` 的真实写回路径
- Phase 8 的重点不是重新发明 bridge，而是把现有 bridge 做稳定性、验证和 UI 收口

---

## Global Execution Rules

- 必须严格按 `Phase 8 -> Phase 9` 顺序执行
- 每个 phase 内必须按 task 顺序执行
- 一次只做一个 task
- 每完成一个 task，先运行该 task 的验证命令
- 只有当前 phase 的 task 级验证和全量验证都通过，才能开始下一个 phase
- 如果某个 phase 阻塞，停在当前 phase，不要提前实现下一 phase
- 不要回退任何已有用户改动
- 不要自行扩 scope

统一不做的事情：
- 不重写 observation / adapter / session matching
- 不新增复杂动画、hover 专属行为或复杂手势
- 不把 panel 再抬回第一层工作台
- 不新增多按钮密集交互
- 不把 Codex / Gemini 全量真实写回并入这一轮

---

## Phase 8 — Reply Bridge Hardening / Intervention Reliability

### Goal
把现有 `ReplyBridgeService` 从“底层已有真实写回能力”推进成“产品层可信、失败可解释、UI 能正确表达”的真实介入路径。

### In Scope
- 统一 island quick action / panel quick action / panel 自由输入的真实写回语义
- 强化 `ReplyBridgeService.validateReply` / `sendReply` 的目标一致性、失败反馈和边界说明
- 让 UI 在发送前明确表达“可发送 / 不可发送 / 需要刷新 / 权限缺失”
- 保持 runtime history 继续记录成功发送 / 拒绝发送
- 补独立 reply bridge 测试

### Out of Scope
- Codex / Gemini 真实写回
- 新 bridge transport
- 守护进程或后台常驻桥接服务
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

### Task 1: Harden reply bridge validation and target consistency

**Files:**
- Modify: `MacIrlandKit/Services/ReplyBridge/ReplyBridgeService.swift`
- Test: `MacIrlandTests/ReplyBridgeServiceTests.swift`

- [ ] **Step 1: Add failing tests for target mismatch and unsupported terminal paths**

Cover at least:
- message empty
- source CLI not Claude Code
- missing `bridgeTarget`
- `replyCapability.status == .unavailable`
- unsupported terminal app identifier
- `windowIdentifier` and `bridgeTarget.terminalContext` mismatch

- [ ] **Step 2: Run focused tests**

Run:
```bash
swift test --filter ReplyBridgeServiceTests
```

- [ ] **Step 3: Implement minimal hardening**

Requirements:
- keep current Claude Code only scope
- keep current Terminal / iTerm writers
- ensure explanations remain user-facing and actionable
- do not silently fall through to generic failure when the code can explain a specific cause

- [ ] **Step 4: Re-run focused tests**

Run:
```bash
swift test --filter ReplyBridgeServiceTests
```

- [ ] **Step 5: Commit**

```bash
git add MacIrlandKit/Services/ReplyBridge/ReplyBridgeService.swift MacIrlandTests/ReplyBridgeServiceTests.swift
git commit -m "feat: harden reply bridge validation"
```

### Task 2: Align island/panel intervention UI with real bridge state

**Files:**
- Modify: `MacIrlandKit/Features/Island/IslandPresentation.swift`
- Modify: `MacIrlandKit/Features/Island/IslandExpandedCardView.swift`
- Modify: `MacIrlandKit/Features/Panel/SessionDetailView.swift`
- Modify: `MacIrlandKit/Features/Panel/PanelView.swift`
- Modify: `MacIrlandKit/Core/State/TaskStateStore.swift`
- Test: `MacIrlandTests/UIDisplayFormattingTests.swift`
- Test: `MacIrlandTests/TaskStateStoreTests.swift`

- [ ] **Step 1: Add failing tests for bridge-state-driven copy**

Cover at least:
- quick action available copy
- quick action unavailable copy
- free text send disabled / guarded when bridge unavailable
- action result still renders one-line explanation

- [ ] **Step 2: Run focused tests**

Run:
```bash
swift test --filter UIDisplayFormattingTests
swift test --filter TaskStateStoreTests
```

- [ ] **Step 3: Implement minimal UI/state alignment**

Requirements:
- island quick action and panel quick action must reuse the same bridge semantics
- panel free text area must clearly express whether sending is possible
- do not add new dense controls
- do not promote panel back to primary layer

- [ ] **Step 4: Re-run focused tests**

Run:
```bash
swift test --filter UIDisplayFormattingTests
swift test --filter TaskStateStoreTests
```

- [ ] **Step 5: Commit**

```bash
git add MacIrlandKit/Features/Island/IslandPresentation.swift MacIrlandKit/Features/Island/IslandExpandedCardView.swift MacIrlandKit/Features/Panel/SessionDetailView.swift MacIrlandKit/Features/Panel/PanelView.swift MacIrlandKit/Core/State/TaskStateStore.swift MacIrlandTests/UIDisplayFormattingTests.swift MacIrlandTests/TaskStateStoreTests.swift
git commit -m "feat: align intervention UI with reply bridge state"
```

### Task 3: Verify Phase 8 end-to-end and document it

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Run phase verification**

Run:
```bash
swift test --filter ReplyBridgeServiceTests
swift test --filter TaskStateStoreTests
swift test --filter UIDisplayFormattingTests
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland"
swift build --package-path "/Users/lijunjie/Documents/AIproject/macirland"
```

- [ ] **Step 2: Launch the app for a real experience pass**

Run:
```bash
cd /Users/lijunjie/Documents/AIproject/macirland
./Scripts/run-dev-app.sh
```

If local permissions allow, verify at least:
- app launches
- panel opens
- one real Claude Code reply path can be exercised or clearly reports why it cannot

- [ ] **Step 3: Update docs**

Update `CLAUDE.md` with:
- current real reply bridge scope
- what is now truly wired vs still out of scope
- any permission caveats that still matter

- [ ] **Step 4: Write execution report**

Write:

- [ ] **Step 5: Commit**

```bash
git commit -m "docs: record phase 8 reply bridge hardening"
```

### Phase 8 Exit Gate
- focused tests pass
- full test suite passes
- build passes
- app launches
- at least one real reply path is either verified or blocked by an explicitly documented permission/environment issue
- `CLAUDE.md` updated
- execution report written

---

## Phase 9 — Product Polish / Stability Closure

### Goal
在真实介入路径收住后，完成最后一轮 copy、边界行为和整体体验收口，让你这次开发完成后就能直接体验产品效果。

### In Scope
- 统一 compact / highlighted / panel 的状态词和 copy
- 收口主要边界行为：
  - 无 session
  - 单 session
  - 多 session 同 tier
  - 高 tier 抢占
  - dismiss 后接力
  - auto-collapse 后接力
  - reply 成功 / reply 失败 / 权限缺失
- 轻量视觉与尺寸细节优化
- 最终回归验证与文档更新

### Out of Scope
- 新产品形态
- 新交互模型
- 架构级重写

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

### Task 1: Normalize user-facing copy across island and panel

**Files:**
- Modify: `MacIrlandKit/Features/Island/IslandPresentation.swift`
- Modify: `MacIrlandKit/Features/Island/IslandStatusStripView.swift`
- Modify: `MacIrlandKit/Features/Island/IslandExpandedCardView.swift`
- Modify: `MacIrlandKit/Features/Panel/PanelView.swift`
- Modify: `MacIrlandKit/Features/Panel/SessionDetailView.swift`
- Test: `MacIrlandTests/UIDisplayFormattingTests.swift`

- [ ] **Step 1: Add failing tests for copy consistency**

Cover at least:
- compact status text
- expanded status/action hint
- panel empty / blocked / actionable copy
- reply success / failure wording consistency

- [ ] **Step 2: Run focused tests**

Run:
```bash
swift test --filter UIDisplayFormattingTests
```

- [ ] **Step 3: Implement minimal copy normalization**

Requirements:
- wording should feel product-facing, not engineering-facing
- do not inflate text volume
- keep island lightweight

- [ ] **Step 4: Re-run focused tests**

Run:
```bash
swift test --filter UIDisplayFormattingTests
```

- [ ] **Step 5: Commit**

```bash
git add MacIrlandKit/Features/Island/IslandPresentation.swift MacIrlandKit/Features/Island/IslandStatusStripView.swift MacIrlandKit/Features/Island/IslandExpandedCardView.swift MacIrlandKit/Features/Panel/PanelView.swift MacIrlandKit/Features/Panel/SessionDetailView.swift MacIrlandTests/UIDisplayFormattingTests.swift
git commit -m "feat: normalize island-first product copy"
```

### Task 2: Close remaining behavior edges

**Files:**
- Modify: `MacIrlandApp/App/IslandCoordinator.swift`
- Modify: `MacIrlandKit/Core/State/TaskStateStore.swift`
- Modify: `MacIrlandKit/Features/Panel/SessionPickerView.swift`
- Test: `MacIrlandTests/TaskStateStoreTests.swift`
- Test: `MacIrlandTests/AppLaunchSupportTests.swift`

- [ ] **Step 1: Add failing tests for behavior edges**

Cover at least:
- same-tier handoff stability
- higher-tier preemption after queue handoff
- dismiss then reopen panel focus consistency
- reply failure leaves meaningful context visible

- [ ] **Step 2: Run focused tests**

Run:
```bash
swift test --filter TaskStateStoreTests
swift test --filter AppLaunchSupportTests
```

- [ ] **Step 3: Implement minimal edge fixes**

Requirements:
- do not reopen previously dismissed session immediately unless ranking rules justify it
- preserve queue handoff behavior from Phase 7
- keep panel selection aligned with island focus

- [ ] **Step 4: Re-run focused tests**

Run:
```bash
swift test --filter TaskStateStoreTests
swift test --filter AppLaunchSupportTests
```

- [ ] **Step 5: Commit**

```bash
git add MacIrlandApp/App/IslandCoordinator.swift MacIrlandKit/Core/State/TaskStateStore.swift MacIrlandKit/Features/Panel/SessionPickerView.swift MacIrlandTests/TaskStateStoreTests.swift MacIrlandTests/AppLaunchSupportTests.swift
git commit -m "fix: close island-first behavior edges"
```

### Task 3: Final validation, app launch, and documentation closure

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Run full verification**

Run:
```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland"
swift build --package-path "/Users/lijunjie/Documents/AIproject/macirland"
```

- [ ] **Step 2: Launch the product and do a final experience pass**

Run:
```bash
cd /Users/lijunjie/Documents/AIproject/macirland
./Scripts/run-dev-app.sh
```

Verify as far as the environment allows:
- app launches successfully
- island appears
- panel opens from island/menu bar/Dock fallback
- one intervention path is visible and understandable
- copy and status transitions feel coherent

- [ ] **Step 3: Update docs**

Update `CLAUDE.md` with:
- current finished state
- known remaining limitations
- what “done enough to experience” means for this repo

- [ ] **Step 4: Write execution report**

Write:

- [ ] **Step 5: Commit**

```bash
git commit -m "docs: record phase 9 product closure"
```

### Phase 9 Exit Gate
- focused tests pass
- full test suite passes
- build passes
- app launches
- product is coherent enough for hands-on experience
- `CLAUDE.md` updated
- execution report written

---

## Final Definition of Done

在完成本计划后，应达到：
- attention queue / handoff 已稳定
- 至少一条真实 reply bridge 路径已被产品层正确表达
- island、highlighted card、panel 三层 copy 与状态一致
- app 能直接启动并体验主要流程
- 主要边界行为有测试覆盖
- `swift test` / `swift build` 通过
- `CLAUDE.md`、Phase 8 report、Phase 9 report 都已落盘

---

## Final Reporting Requirements

完整执行完 Phase 8-9 后，最终汇报必须包含：
- 实际修改的文件列表
- Phase 8 / 9 各自的完成情况
- 各 task 的测试命令
- 最终全量验证命令
- 是否更新了 `CLAUDE.md`
- 2 份 execution report 的绝对路径
- 是否存在偏离计划的地方；如果有，逐条说明原因

---

## Sequencing Reminder

最重要的规则：

**不要把 Phase 8 和 Phase 9 的任务混着做。**

正确顺序只有一种：

1. 完整完成 Phase 8，并验证通过
2. 完整完成 Phase 9，并验证通过

如果 Phase 8 卡住，就停在 Phase 8，不要提前实现 Phase 9。
