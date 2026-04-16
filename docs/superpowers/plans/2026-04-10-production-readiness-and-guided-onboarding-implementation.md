# Production Readiness And Guided Onboarding Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把当前版本从“形态完整、测试通过”推进到“第一次打开就能理解能不能用、缺什么、下一步该做什么”的可用产品状态。

**Architecture:** 当前代码已经完成了 island-first 形态、Claude-first tray / panel、自动刷新、transition-based sound、轻量 diagnostics 和较强的测试覆盖。真正阻碍“可用”的最后一段已经不再是视觉，而是首次使用体验：当权限没开、观测没通、reply bridge 暂不可用、或当前没有可操作 Claude 会话时，用户还需要自己推断发生了什么。下一轮应把这些状态收成一个统一的 readiness / onboarding 体验层，让产品在“可用 / 不可用 / 部分可用”之间有清晰指引。

**Tech Stack:** Swift, SwiftUI, AppKit, Observation, XCTest

---

## Inputs

### Must review first
- `docs/superpowers/plans/2026-04-10-claude-first-surface-alignment-implementation.md`
- current app behavior in panel diagnostics / blocked states

### Why this round matters
- 现在产品“像一个产品”了，但未必“第一次就能用明白”
- 首次打开时，用户仍可能遇到：无权限、无会话、观测失败、reply 不可用
- 这些状态目前分散在 diagnostics 和细碎文案里，不够 onboarding-friendly

---

## File Structure

### Modify
- `MacIrlandKit/Core/State/TaskStateStore.swift`
- `MacIrlandKit/Features/Panel/PanelPresentation.swift`
- `MacIrlandKit/Features/Panel/PanelView.swift`
- `MacIrlandKit/Features/Panel/SessionDetailView.swift`
- `MacIrlandKit/Features/Diagnostics/DiagnosticsSectionView.swift`
- `MacIrlandApp/App/AppDelegate.swift`
- `MacIrlandTests/TaskStateStoreTests.swift`
- `MacIrlandTests/UIDisplayFormattingTests.swift`
- `MacIrlandTests/AppLaunchSupportTests.swift`
- `CLAUDE.md`

### Create

---

## Task 1: Introduce a single readiness / onboarding model

**Files:**
- Modify: `MacIrlandKit/Core/State/TaskStateStore.swift`
- Modify: `MacIrlandKit/Features/Panel/PanelPresentation.swift`
- Modify: `MacIrlandTests/TaskStateStoreTests.swift`
- Modify: `MacIrlandTests/UIDisplayFormattingTests.swift`

- [ ] **Step 1: Define product-level readiness states**

Add a single product-facing readiness/onboarding representation that can answer:
- app is fully ready
- app is partially ready but blocked by permissions / observation
- app is ready but no Claude Code session is currently active
- app sees a session but reply path is not ready

Do not force views to recompute this ad hoc from raw capability status and diagnostics.

- [ ] **Step 2: Keep it user-facing, not engineering-facing**

This model should produce:
- title
- short explanation
- recommended next action

It should not expose raw internal details like diagnostics structs or reader counts.

- [ ] **Step 3: Add focused tests**

Required coverage:
- blocked observation produces permission/setup-oriented readiness
- healthy app with no Claude sessions produces “start Claude Code” readiness
- active Claude session with unavailable reply path produces “view only / limited action” readiness

- [ ] **Step 4: Run focused verification**

Run:
```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter TaskStateStoreTests
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter UIDisplayFormattingTests
```

---

## Task 2: Add guided onboarding / blocked-state UI to the panel primary surface

**Files:**
- Modify: `MacIrlandKit/Features/Panel/PanelView.swift`
- Modify: `MacIrlandKit/Features/Panel/SessionDetailView.swift`
- Modify: `MacIrlandKit/Features/Panel/PanelPresentation.swift`
- Modify: `MacIrlandTests/UIDisplayFormattingTests.swift`
- Modify: `MacIrlandTests/AppLaunchSupportTests.swift`

- [ ] **Step 1: Surface readiness clearly in the primary panel layer**

When the product is not fully ready, the panel should clearly explain:
- what is missing
- whether the app is partially working
- what the user should do next

This belongs in the primary panel surface, not buried only in diagnostics.

- [ ] **Step 2: Keep it compact and actionable**

Requirements:
- no giant wizard
- no multiple-step full-screen onboarding
- just one clear guidance card / state block in the primary panel surface

The guidance should feel product-like, not like an engineer debug dump.

- [ ] **Step 3: Make “no current Claude session” a first-class state**

Do not treat “no Claude session” as a vague empty state.
Treat it as a legitimate ready-but-idle product state with concise guidance.

- [ ] **Step 4: Add focused tests**

Required coverage:
- blocked state no longer relies on diagnostics-only messaging
- no-session state is expressed as a clear Claude-first onboarding message
- limited reply capability state has a user-facing explanation

- [ ] **Step 5: Run focused verification**

Run:
```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter UIDisplayFormattingTests
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter AppLaunchSupportTests
```

---

## Task 3: Add direct setup affordances where the app already knows the next step

**Files:**
- Modify: `MacIrlandApp/App/AppDelegate.swift`
- Modify: `MacIrlandKit/Features/Panel/PanelView.swift`
- Modify: `MacIrlandTests/AppLaunchSupportTests.swift`

- [ ] **Step 1: Wire obvious setup actions**

Where the app already knows the right next step, add direct affordances such as:
- open settings / permissions guidance
- open app settings
- re-open the panel after setup if needed

Only add actions the app can own clearly.
Do not add speculative buttons.

- [ ] **Step 2: Keep the fallback path clear**

If an action cannot be performed automatically, the product should still present one short next step instead of forcing the user to read a diagnostic paragraph.

- [ ] **Step 3: Add focused tests**

Required coverage:
- blocked/setup state renders a direct affordance when available
- unsupported path still gives a concise single next step

- [ ] **Step 4: Run focused verification**

Run:
```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter AppLaunchSupportTests
```

---

## Task 4: Full runtime walkthrough and docs closure

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

1. fresh/idle state: user can understand that the app is ready but waiting for Claude Code
2. blocked observation/permission state: user sees one clear next step
3. active Claude session: user can understand current status and whether reply is available
4. partial capability state: user can tell the difference between “watching only” and “fully interactive”

- [ ] **Step 3: Update docs**

Update `CLAUDE.md` so it reflects:
- Claude-first panel surface
- readiness / onboarding behavior
- where diagnostics fit relative to primary guidance

- [ ] **Step 4: Write execution report**

Create:

Report must include:
1. objective recap
2. readiness/onboarding summary
3. file changes
4. task execution details
5. verification matrix
6. deviations from plan
7. remaining risks

---

## Definition of Done

DoD:
- product has a single user-facing readiness model
- primary panel surface can explain blocked / idle / limited-interaction states without forcing the user into diagnostics
- obvious setup actions are directly reachable when possible
- `swift test` passes
- `swift build` passes
- runtime walkthrough completed
- `CLAUDE.md` updated
- execution report written to the fixed path
