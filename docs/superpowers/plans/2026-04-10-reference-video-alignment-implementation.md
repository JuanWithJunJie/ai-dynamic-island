# Reference Video Alignment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把当前 island / multi-session tray / 图标反馈继续往参考视频靠拢，重点补齐像素图标状态系统、tray 触发语义、颜色语义和真实体验闭环。

**Architecture:** 当前代码已经具备基础稳定性：自动刷新、multi-session tray、完成提示音、第二会话动态加入测试都已落地，且测试全绿。下一步不再扩功能面，而是统一视觉状态语言。核心是把“运行中 / 待机 / 完成”的状态表达从零散实现收敛成同一套 sprite-based system，并让 compact island、expanded card、multi-session tray 都消费同一套 presentation 结果。同时收紧 multi-session tray 的触发条件，确保它更接近参考视频而不是简单的 `sessions.count > 1`。

**Tech Stack:** Swift, SwiftUI, AppKit, Observation, XCTest

---

## Inputs

### Must review first
- `example/macisland-run.png`
- `example/vibe-irland-2.mp4`
- `example/vibe-irland-3.mp4`

### Current gaps to close
- 目前动态图标只主要体现在 menu bar `AnimatedStatusIcon`，不是整套 island 体系
- `StatusSpriteView` 仍是静态字符图标，不符合参考视频
- `idle` 尚未拥有轻量动画
- tray 触发条件仍偏粗，未收成“多个 Claude Code 会话”语义
- 颜色语义仍未完全对齐：
  - 运行中应偏绿色动态
  - 完成后应偏橙色静止
- execution report 对“遗留问题无”判断过乐观，缺少更严格实机体验验证

---

## File Structure

### Modify
- `MacIrlandKit/DesignSystem/StatusViews.swift`
- `MacIrlandKit/Features/Icon/AnimatedStatusIcon.swift`
- `MacIrlandKit/Features/Island/IslandPresentation.swift`
- `MacIrlandKit/Features/Island/IslandStatusStripView.swift`
- `MacIrlandKit/Features/Island/IslandExpandedCardView.swift`
- `MacIrlandKit/Features/Island/IslandMultiSessionTrayView.swift`
- `MacIrlandKit/Features/Island/IslandSurfaceView.swift`
- `MacIrlandApp/App/IslandCoordinator.swift`
- `MacIrlandApp/App/MenuBarStatusLabel.swift`
- `MacIrlandKit/Core/State/TaskStateStore.swift`
- `MacIrlandTests/UIDisplayFormattingTests.swift`
- `MacIrlandTests/AppLaunchSupportTests.swift`
- `MacIrlandTests/TaskStateStoreTests.swift`
- `CLAUDE.md`

### Create

---

## Task 1: Unify icon state language into one sprite-based system

**Files:**
- Modify: `MacIrlandKit/DesignSystem/StatusViews.swift`
- Modify: `MacIrlandKit/Features/Icon/AnimatedStatusIcon.swift`
- Modify: `MacIrlandKit/Features/Island/IslandPresentation.swift`
- Modify: `MacIrlandTests/UIDisplayFormattingTests.swift`

- [ ] **Step 1: Define a single semantic model for icon states**

The system should expose a shared state concept, for example:
- `idle`
- `running`
- `completed`

Mapping requirements:
- `running` = visibly active, green, more animated
- `idle` / ready-like = lightly animated, calmer
- `completed` = static, orange

Do not keep separate, drifting logic between menu bar and island views.

- [ ] **Step 2: Replace generic pulse-only animation with sprite-style motion**

Reference target:
- `vibe-irland-3.mp4`

Requirements:
- no generic spinner
- no plain scale pulse as the only behavior
- motion should read as pixel/sprite frame cycling
- animation must remain lightweight and must not resize the surface

- [ ] **Step 3: Apply the same icon language everywhere**

Required consumers:
- compact island
- highlighted card
- multi-session tray rows
- menu bar fallback

- [ ] **Step 4: Run focused tests**

Run:
```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter UIDisplayFormattingTests
```

---

## Task 2: Tighten multi-session tray eligibility and routing

**Files:**
- Modify: `MacIrlandApp/App/IslandCoordinator.swift`
- Modify: `MacIrlandKit/Core/State/TaskStateStore.swift`
- Modify: `MacIrlandKit/Features/Island/IslandMultiSessionTrayView.swift`
- Modify: `MacIrlandKit/Features/Island/IslandSurfaceView.swift`
- Modify: `MacIrlandTests/TaskStateStoreTests.swift`
- Modify: `MacIrlandTests/AppLaunchSupportTests.swift`

- [ ] **Step 1: Introduce a dedicated “multiple Claude Code sessions” signal**

Do not keep tray eligibility as raw `store.sessions.count > 1`.

Instead, derive a clearer condition:
- multiple relevant Claude Code sessions exist
- tray should reflect those sessions first

Do not widen scope into a generalized tray for every possible CLI if current product is still Claude-first.

- [ ] **Step 2: Refine hover routing**

Target behavior:
- single-session compact island: hover can still route directly to panel
- multi-Claude-session compact island: hover opens tray
- tray row click opens panel focused to selected session

- [ ] **Step 3: Keep tray lightweight**

Reference target:
- `vibe-irland-2.mp4`

Requirements:
- row content remains compact
- no nested cards
- no full diagnostic content
- no mini-panel behavior

- [ ] **Step 4: Run focused tests**

Run:
```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter TaskStateStoreTests
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter AppLaunchSupportTests
```

---

## Task 3: Align alert / running / completion presentation semantics

**Files:**
- Modify: `MacIrlandKit/Features/Island/IslandPresentation.swift`
- Modify: `MacIrlandApp/App/IslandCoordinator.swift`
- Modify: `MacIrlandKit/DesignSystem/StatusViews.swift`
- Modify: `MacIrlandTests/UIDisplayFormattingTests.swift`
- Modify: `MacIrlandTests/TaskStateStoreTests.swift`

- [ ] **Step 1: Keep alert compact when work is still progressing**

Reference target:
- `macisland-fix.png`

Requirements:
- `.alert` should remain visible
- but should not automatically force the large highlighted card when Claude Code is still clearly working
- blocking states still remain eligible for stronger interruption

- [ ] **Step 2: Align color semantics**

Target:
- `running` visual language leans green
- `completed` visual language leans orange
- `idle` remains calmer than running

This needs to be consistent across:
- compact island
- tray rows
- menu bar fallback

- [ ] **Step 3: Keep completion sound + completion visual coupled**

Requirements:
- completion sound fires once when session truly transitions to `.completed`
- icon simultaneously settles into static orange completed state
- avoid replaying sound or re-triggering transition every refresh

- [ ] **Step 4: Run focused tests**

Run:
```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter UIDisplayFormattingTests
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter TaskStateStoreTests
```

---

## Task 4: Real experience verification and doc closure

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Run full verification**

Run:
```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland"
swift build --package-path "/Users/lijunjie/Documents/AIproject/macirland"
```

- [ ] **Step 2: Run explicit real-world checks**

Required runtime checks:

1. launch app
2. start one Claude Code session and observe compact island
3. leave one Claude Code session idle/ready and confirm lighter idle motion
4. start a second Claude Code session and confirm tray behavior
5. complete a task and confirm sound + orange static icon

Success criteria:
- second session join does not crash app
- compact island remains small
- idle/running/completed states are visually distinct
- multi-session hover opens a lightweight tray
- tray rows use the same icon state language as compact island

- [ ] **Step 3: Update docs**

Update `CLAUDE.md` with only current behavior:
- unified icon state language
- multi-session tray trigger semantics
- alert suppression behavior

- [ ] **Step 4: Write execution report**

Create:

Report must include:
1. objective recap
2. gaps found in previous implementation
3. file changes
4. task execution details
5. verification matrix
6. deviations from plan
7. remaining risks

---

## Definition of Done

DoD:
- compact island, menu bar, highlighted card, and tray rows share one icon state language
- idle / running / completed are visually distinct
- running is green-leaning and animated
- completed is orange-leaning and static
- multi-session tray only triggers under the intended Claude Code scenario
- alert no longer over-expands while work is still progressing
- `swift test` passes
- `swift build` passes
- `CLAUDE.md` updated
- execution report written to the fixed path
