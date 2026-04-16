# Claude-First Surface Alignment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把当前产品从“tray 是 Claude-first、其他层仍混合多 CLI”收口到更一致的 Claude-first 体验，让 compact island、tray、panel 首屏表达同一产品意图。

**Architecture:** 当前版本的工程稳定性、自动刷新、transition-based sound、Claude-first tray 和轻量 runtime diagnostics 都已经落地，且测试/构建为绿。剩下最明显的产品割裂是：tray 已明确只服务 Claude Code，但 panel/picker/主工作区仍然同时把 Codex、Gemini 等会话放在与 Claude 同等的主层级里。下一轮不再新增系统能力，而是调整 surface scope：让主产品层优先面向 Claude Code，把非 Claude 会话降级为次级上下文或诊断信息，减少认知冲突。

**Tech Stack:** Swift, SwiftUI, AppKit, Observation, XCTest

---

## Inputs

### Must review first
- `docs/superpowers/plans/2026-04-10-runtime-verification-and-claude-focus-implementation.md`
- `example/vibe-irland-2.mp4`
- `example/vibe-irland-3.mp4`

### Why this round matters
- tray 已是 Claude-first，但 panel picker 和部分 surface 仍混合展示其他 CLI
- 产品主层级目前存在“顶部告诉你这是 Claude 产品，展开后又像通用多 CLI 控制台”的割裂
- 现在最值得做的是收紧主 surface 的产品边界，而不是继续扩交互

---

## File Structure

### Modify
- `MacIrlandKit/Core/State/TaskStateStore.swift`
- `MacIrlandKit/Features/Panel/PanelPresentation.swift`
- `MacIrlandKit/Features/Panel/PanelView.swift`
- `MacIrlandKit/Features/Panel/SessionPickerView.swift`
- `MacIrlandKit/Features/Panel/SessionDetailView.swift`
- `MacIrlandKit/Features/Diagnostics/DiagnosticsSectionView.swift`
- `MacIrlandTests/TaskStateStoreTests.swift`
- `MacIrlandTests/UIDisplayFormattingTests.swift`
- `MacIrlandTests/AppLaunchSupportTests.swift`
- `CLAUDE.md`

### Create

---

## Task 1: Introduce a Claude-first panel session source of truth

**Files:**
- Modify: `MacIrlandKit/Core/State/TaskStateStore.swift`
- Modify: `MacIrlandTests/TaskStateStoreTests.swift`

- [ ] **Step 1: Define the panel-facing Claude-first session set**

Add or refine a single source of truth for which sessions should appear in the panel’s primary navigation and primary work area.

Target behavior:
- Claude Code sessions remain primary
- non-Claude sessions are not removed from the app entirely, but should not compete equally in the main product layer

Do not overload `traySessions` for this. The panel needs its own clearly named product-facing filter.

- [ ] **Step 2: Preserve selection and focus behavior**

If the current selected session becomes non-primary under the new filter:
- fall back cleanly to the best available Claude session
- do not crash or leave the panel in an empty broken state

- [ ] **Step 3: Add focused regression tests**

Required coverage:
- primary panel sessions include Claude sessions
- non-Claude sessions do not appear in the primary panel set
- selection falls back predictably when current selection is excluded from the primary set

- [ ] **Step 4: Run focused verification**

Run:
```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter TaskStateStoreTests
```

---

## Task 2: Align panel copy and navigation with Claude-first scope

**Files:**
- Modify: `MacIrlandKit/Features/Panel/PanelPresentation.swift`
- Modify: `MacIrlandKit/Features/Panel/PanelView.swift`
- Modify: `MacIrlandKit/Features/Panel/SessionPickerView.swift`
- Modify: `MacIrlandKit/Features/Panel/SessionDetailView.swift`
- Modify: `MacIrlandTests/UIDisplayFormattingTests.swift`
- Modify: `MacIrlandTests/AppLaunchSupportTests.swift`

- [ ] **Step 1: Make the primary panel read like a Claude workspace**

Adjust panel header / subtitle / empty-state copy so the top-level product message is clearly about Claude Code session handling.

Do not broaden the copy back into “all CLI control center”.

- [ ] **Step 2: De-emphasize or relocate non-Claude context**

Allowed directions:
- hide non-Claude sessions from the primary picker
- or move them into a quieter secondary/diagnostic area

Not allowed:
- deleting non-Claude data from the store
- removing multi-CLI observability from diagnostics

- [ ] **Step 3: Keep island → panel handoff coherent**

Requirements:
- clicking compact / tray / highlighted paths should land in the same Claude-first panel surface
- panel should not suddenly look like a generic mixed-CLI dashboard

- [ ] **Step 4: Add focused tests**

Required coverage:
- panel copy reflects Claude-first scope
- picker/navigation uses the Claude-first panel session source
- empty-state and fallback selection behave correctly

- [ ] **Step 5: Run focused verification**

Run:
```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter UIDisplayFormattingTests
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter AppLaunchSupportTests
```

---

## Task 3: Keep diagnostics multi-CLI aware without polluting the product layer

**Files:**
- Modify: `MacIrlandKit/Features/Diagnostics/DiagnosticsSectionView.swift`
- Modify: `MacIrlandTests/UIDisplayFormattingTests.swift`

- [ ] **Step 1: Preserve multi-CLI visibility only where it is useful**

Diagnostics may continue to mention non-Claude sessions or raw reader state, but this should remain clearly engineering/support context.

Do not let diagnostics wording undermine the Claude-first product story.

- [ ] **Step 2: Re-check runtime diagnostics wording**

Ensure diagnostics continue to explain:
- tray count / eligibility
- island focus state

but still read as low-priority introspection, not product chrome.

- [ ] **Step 3: Run focused verification**

Run:
```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter UIDisplayFormattingTests
```

---

## Task 4: Full verification, runtime walkthrough, and docs

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Run full automated verification**

Run:
```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland"
swift build --package-path "/Users/lijunjie/Documents/AIproject/macirland"
```

- [ ] **Step 2: Run explicit runtime walkthrough**

Required checks:

1. Claude-only workflow: compact island, tray, panel all read coherently as one Claude-first product
2. mixed workflow: a non-Claude session does not hijack the tray or primary panel surface
3. diagnostics still expose enough runtime information to understand what the app is seeing
4. sound, alert, hover tray, and focus handoff still behave as before

- [ ] **Step 3: Update docs**

Update `CLAUDE.md` so it reflects only current truth:
- tray is Claude-first
- panel primary surface is Claude-first
- diagnostics remain the place for lower-priority multi-CLI introspection

- [ ] **Step 4: Write execution report**

Create:

Report must include:
1. objective recap
2. product-scope alignment summary
3. file changes
4. task execution details
5. verification matrix
6. deviations from plan
7. remaining risks

---

## Definition of Done

DoD:
- panel primary surface is Claude-first and no longer visually conflicts with tray semantics
- non-Claude sessions are de-emphasized or relocated out of the primary product layer
- diagnostics remain useful and low-priority
- `swift test` passes
- `swift build` passes
- runtime walkthrough completed
- `CLAUDE.md` updated
- execution report written to the fixed path
