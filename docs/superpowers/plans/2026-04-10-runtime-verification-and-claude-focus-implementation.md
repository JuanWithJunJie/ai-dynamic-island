# Runtime Verification And Claude-Focus Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把当前版本从“测试和构建都通过”推进到“可以稳定长期体验”，重点补齐真实运行验证、Claude-first tray 语义收口，以及必要的可观测性。

**Architecture:** 当前代码已经具备完整的 island-first 主链路，最新报告也证明 transition-based 声音测试、`traySessions` 单一数据源和 alert 轻提示都已经落地。此时最值得做的不是继续铺 UI，而是把剩余的不确定性收掉：一是 tray 仍允许“高置信度 + bridge”的非 Claude 会话进入，和当前产品重心不完全一致；二是 runtime verification 仍主要存在于执行报告文字里，缺少面向真实体验的验证/诊断支撑。下一轮应聚焦“Claude-first 体验收口 + 真实运行验证闭环 + 必要的轻量诊断辅助”。

**Tech Stack:** Swift, SwiftUI, AppKit, Observation, XCTest

---

## Inputs

### Must review first
- `docs/superpowers/plans/2026-04-10-final-experience-hardening-implementation.md`
- `example/vibe-irland-2.mp4`
- `example/vibe-irland-3.mp4`

### Why another round is still useful
- 自动化测试已绿，但“长期体验是否稳”仍主要靠口头 checklist
- `traySessions` 仍允许非 Claude 的高置信度会话进入 tray，这与当前产品的 Claude-first 目标并不完全一致
- 运行中如果体验出现偏差，当前缺少足够轻量的运行态线索来判断是识别、筛选、还是 hover/tray 路由问题

---

## File Structure

### Modify
- `MacIrlandKit/Core/State/TaskStateStore.swift`
- `MacIrlandApp/App/IslandCoordinator.swift`
- `MacIrlandKit/Features/Island/IslandMultiSessionTrayView.swift`
- `MacIrlandKit/Features/Island/IslandStatusStripView.swift`
- `MacIrlandKit/Features/Diagnostics/DiagnosticsSectionView.swift`
- `MacIrlandTests/TaskStateStoreTests.swift`
- `MacIrlandTests/AppLaunchSupportTests.swift`
- `MacIrlandTests/UIDisplayFormattingTests.swift`
- `CLAUDE.md`

### Create

---

## Task 1: Tighten tray semantics to Claude-first behavior

**Files:**
- Modify: `MacIrlandKit/Core/State/TaskStateStore.swift`
- Modify: `MacIrlandApp/App/IslandCoordinator.swift`
- Modify: `MacIrlandKit/Features/Island/IslandMultiSessionTrayView.swift`
- Modify: `MacIrlandTests/TaskStateStoreTests.swift`
- Modify: `MacIrlandTests/AppLaunchSupportTests.swift`

- [ ] **Step 1: Restrict tray sessions to the actual product target**

Revisit `traySessions` and make it explicitly match current product intent:
- multiple Claude Code sessions should drive tray
- unrelated non-Claude sessions should not quietly enter the tray just because they have high confidence or a bridge target

Do not broaden the product again in this round. Prefer a simpler Claude-first rule over a more “general” but less predictable rule.

- [ ] **Step 2: Keep hover and row-click behavior unchanged**

Requirements:
- 1 Claude Code session -> no multi-session tray
- 2+ Claude Code sessions -> tray appears
- tray row click still opens panel and focuses the clicked session

- [ ] **Step 3: Add focused regression tests**

Required coverage:
- two Claude Code sessions are tray-eligible
- one Claude Code + one non-Claude high-confidence session is not enough to produce tray
- terminal Claude sessions do not keep tray alive

- [ ] **Step 4: Run focused verification**

Run:
```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter TaskStateStoreTests
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter AppLaunchSupportTests
```

---

## Task 2: Add lightweight runtime observability for tray/focus decisions

**Files:**
- Modify: `MacIrlandKit/Core/State/TaskStateStore.swift`
- Modify: `MacIrlandKit/Features/Diagnostics/DiagnosticsSectionView.swift`
- Modify: `MacIrlandTests/UIDisplayFormattingTests.swift`

- [ ] **Step 1: Expose minimal user-facing runtime diagnostics**

Add only the smallest amount of information needed to understand island behavior when it feels wrong.

Good candidates:
- current preferred island session
- current tray session count
- whether tray is eligible

This should live in low-priority diagnostics only, not in the main island or panel header.

- [ ] **Step 2: Keep diagnostics quiet and engineering-only**

Do not surface raw internal model dumps.
Do not increase first-screen noise.
The diagnostics should help debug real runtime behavior without changing the product feel.

- [ ] **Step 3: Add focused tests**

Required coverage:
- diagnostics copy stays low-priority
- tray-session / focus-related diagnostics reflect the Claude-first rule

- [ ] **Step 4: Run focused verification**

Run:
```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter UIDisplayFormattingTests
```

---

## Task 3: Perform explicit runtime verification and small polish

**Files:**
- Modify: `MacIrlandKit/Features/Island/IslandStatusStripView.swift`
- Modify: `CLAUDE.md`

- [ ] **Step 1: Re-check compact/tray copy after Claude-first tightening**

Make only small polish edits if needed so compact/tray wording still reads correctly after the narrowed tray rule.

Do not redesign the UI.

- [ ] **Step 2: Run full verification**

Run:
```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland"
swift build --package-path "/Users/lijunjie/Documents/AIproject/macirland"
```

- [ ] **Step 3: Run explicit runtime checks**

Required manual/runtime checks:

1. one Claude Code session: no tray, compact island still works
2. two Claude Code sessions: tray appears and row click focuses correctly
3. one Claude Code + one unrelated session: tray does not appear
4. sound cues still behave once-per-transition
5. alert remains soft and does not incorrectly force large interruption

- [ ] **Step 4: Update docs and write execution report**

Update `CLAUDE.md` so it only reflects currently true behavior:
- tray is Claude-first
- diagnostics expose minimal tray/focus runtime state
- runtime verification was performed

Create:

Report must include:
1. objective recap
2. product-scope tightening summary
3. file changes
4. task execution details
5. verification matrix
6. deviations from plan
7. remaining risks

---

## Definition of Done

DoD:
- tray behavior is explicitly Claude-first
- runtime diagnostics can explain island/tray focus decisions without polluting the main UI
- full tests pass
- build passes
- explicit runtime checks are documented as completed
- `CLAUDE.md` updated
- execution report written to the fixed path
