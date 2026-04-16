# Concurrent Session Stability And Hover Panel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 先修复“应用运行中再打开一个新的 Claude Code 会话会闪退”的稳定性问题，再收口 island 交互：缩小顶部胶囊、让非阻塞告警不自动弹出大卡片、在多 Claude Code 会话时通过 hover 展开轻量多会话 tray，并补上 Claude Code 任务完成时的原创 chiptune 声音提示与运行/完成图标状态反馈。

**Architecture:** 当前 crash regression fix 已经收回了 duplicate-session / attention regression 主线，但产品层还有三件事未完成：

1. 真实运行中新增第二个 Claude Code 会话仍可能触发闪退，说明 multi-session 动态加入路径还不够稳
2. 当前 compact island 太宽，挡住顶边其他应用
3. 当前 `.alert` 仍会被视为自动弹出的 highlighted 候选，但用户希望“CLI 还在继续工作时，告警只作为提示，不应强制弹出”
4. 当前完成态虽然有 `SoundMode` / `SoundCue.completed` 模型，但没有实际的任务完成提示音落地
5. 当前 island 左侧图标缺少明确的“运行中 / 待机 / 已完成”状态反馈；用户参考 `vibe-irland-3.mp4`，希望使用像素图标帧动画，而且这种状态语言不仅出现在顶部 compact island，也出现在展开后的 multi-session tray 行内

这轮实现应该把稳定性放在第一优先级，UI 只做和新交互目标直接相关的最小必要调整。

**Tech Stack:** Swift, SwiftUI, AppKit, Observation, `TaskStateStore`, `IslandCoordinator`, `PanelCoordinator`, XCTest

---

## Inputs

### Execution report to review first

### Visual references to review first
- `example/macisland-fix.png`
- `example/macisland-run.png`
- `example/vibe-irland-3.mp4`

### User intent distilled
- `macisland-fix.png`
  如果 Claude Code 仍在继续工作，出现告警时不应该自动弹出大卡片
- `macisland-run.png`
  当前顶部灵动胶囊太大，挡住屏幕内容；希望只比刘海稍微大一点
- 新交互
  鼠标移到 island 上时：
  - 单会话时可以继续直达 panel
  - 多 Claude Code 会话时优先展开轻量 multi-session tray，参考 `vibe-irland-2.mp4`
  - tray 行内也要能看出不同 session 的运行中 / 待机状态，参考 `vibe-irland-3.mp4`
- 运行时稳定性
  如果 app 已在运行，再新打开一个 Claude Code 会话，当前仍会闪退

---

## File Structure

### Modify
- `MacIrlandApp/App/IslandCoordinator.swift`
- `MacIrlandApp/App/PanelCoordinator.swift`
- `MacIrlandApp/App/RefreshCoordinator.swift`
- `MacIrlandApp/App/SoundCoordinator.swift`
- `MacIrlandKit/Core/State/TaskStateStore.swift`
- `MacIrlandKit/Features/Island/IslandPresentation.swift`
- `MacIrlandKit/Features/Island/IslandStatusStripView.swift`
- `MacIrlandKit/Features/Island/IslandExpandedCardView.swift`
- `MacIrlandKit/Features/Island/IslandSurfaceView.swift`
- `MacIrlandKit/Features/Island/IslandMultiSessionTrayView.swift`
- `MacIrlandKit/Core/Models/TaskModels.swift`
- `MacIrlandTests/TaskStateStoreTests.swift`
- `MacIrlandTests/AppLaunchSupportTests.swift`
- `MacIrlandTests/UIDisplayFormattingTests.swift`
- `CLAUDE.md`

### Create
- `MacIrlandApp/Resources/Sounds/claude-complete-chiptune.wav`

---

## Task 1: Reproduce and root-cause the “new session while running” crash

**Files:**
- Modify: `MacIrlandTests/TaskStateStoreTests.swift`
- Modify: `MacIrlandTests/AppLaunchSupportTests.swift`

- [ ] **Step 1: Reproduce the dynamic multi-session join scenario in tests**

Add focused coverage for this sequence:

1. app starts with one Claude Code session
2. auto-refresh is active
3. a second distinct Claude Code session appears during runtime
4. store refreshes while island / panel selection logic is active
5. app must not crash, and final session set must be stable

Required assertions:
- two distinct sessions remain after refresh
- no duplicate IDs
- `preferredIslandSession` and `islandAttentionSessions` remain valid
- selection / highlighted state does not point at a now-invalid session ID

- [ ] **Step 2: Inspect the actual crash trigger path**

Before changing behavior, explicitly determine whether the remaining crash comes from:

- session identity / dedup still being wrong for live-join scenarios
- `RefreshCoordinator` reentrancy / task overlap
- `IslandCoordinator` mode recompute using stale IDs while sessions mutate
- panel handoff / selection reconciliation against changing session arrays

Do not assume it is still the old duplicate-session bug without reproducing it.

- [ ] **Step 3: Run focused tests**

Run:
```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter TaskStateStoreTests
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter AppLaunchSupportTests
```

---

## Task 2: Fix concurrent session join stability without backing off 1s refresh

**Files:**
- Modify: `MacIrlandKit/Core/State/TaskStateStore.swift`
- Modify: `MacIrlandApp/App/RefreshCoordinator.swift`
- Modify: `MacIrlandApp/App/IslandCoordinator.swift`
- Modify: `MacIrlandApp/App/PanelCoordinator.swift`
- Modify: tests as needed

- [ ] **Step 1: Stabilize store refresh against live-arriving sessions**

If dynamic session arrival can invalidate focused IDs mid-refresh, fix this in store/coordinator semantics.

Requirements:
- no stale selected / highlighted session references after refresh
- no invalid ID handoff from island to panel
- no crash when sessions grow from 1 -> 2 during polling

- [ ] **Step 2: Keep 1-second refresh intact**

Do not “fix” the crash by reducing polling frequency.

Allowed hardening:
- stronger single-flight semantics
- coalescing pending refresh requests
- safer selection/highlight reconciliation after refresh

- [ ] **Step 3: Re-run focused tests**

Run:
```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter TaskStateStoreTests
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter AppLaunchSupportTests
```

Expected:
- crash reproduction coverage passes
- previous crash-fix coverage remains green

---

## Task 3: Shrink compact island to a notch-adjacent size

**Files:**
- Modify: `MacIrlandApp/App/IslandCoordinator.swift`
- Modify: `MacIrlandKit/Features/Island/IslandStatusStripView.swift`
- Modify: `MacIrlandKit/Features/Island/IslandPresentation.swift`
- Modify: `MacIrlandTests/UIDisplayFormattingTests.swift`
- Modify: `MacIrlandTests/AppLaunchSupportTests.swift`

- [ ] **Step 1: Reduce compact footprint**

Current compact size (`520 x 44`) is too wide.

Target:
- make compact island only slightly larger than the notch visually
- prefer a compact width in the ~`340-380pt` range
- keep height tight (`40-44pt`)

Do not rely on a device-specific notch database.
Use a stable compact width strategy that works across current notch Macs.

- [ ] **Step 2: Preserve readability**

Even after shrinking, compact island must still show:
- icon
- status text
- session count

If needed:
- reduce horizontal padding
- shorten copy
- demote / truncate secondary cue

- [ ] **Step 3: Re-run focused tests**

Run:
```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter UIDisplayFormattingTests
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter AppLaunchSupportTests
```

---

## Task 4: Suppress auto-popup for non-blocking alerts while work is still progressing

**Files:**
- Modify: `MacIrlandKit/Features/Island/IslandPresentation.swift`
- Modify: `MacIrlandApp/App/IslandCoordinator.swift`
- Modify: `MacIrlandTests/TaskStateStoreTests.swift`
- Modify: `MacIrlandTests/UIDisplayFormattingTests.swift`

- [ ] **Step 1: Introduce a stricter highlighted eligibility policy**

User intent is:
- if Claude Code is still continuing work, warning/alert should not automatically expand a big island card

Implementation direction:
- treat `.alert` as a softer attention state than blocking states
- `.waitingInput`, `.failed`, `.contextLost` remain eligible for automatic highlighted presentation
- `.alert` should prefer compact signaling unless there is no stronger/blocking state and the plan explicitly needs a popup

Do not remove alert visibility entirely; downgrade its presentation priority.

- [ ] **Step 2: Update island copy / presentation accordingly**

Compact island should still communicate that something needs attention, but without forcing the expanded card in the “still running” scenario illustrated by `macisland-fix.png`.

- [ ] **Step 3: Re-run focused tests**

Run:
```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter TaskStateStoreTests
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter UIDisplayFormattingTests
```

---

## Task 5: Show a lightweight multi-session tray on hover when multiple Claude Code sessions exist

**Files:**
- Modify: `MacIrlandKit/Features/Island/IslandSurfaceView.swift`
- Modify: `MacIrlandKit/Features/Island/IslandStatusStripView.swift`
- Modify: `MacIrlandApp/App/IslandCoordinator.swift`
- Modify: `MacIrlandKit/Features/Island/IslandPresentation.swift`
- Create: `MacIrlandKit/Features/Island/IslandMultiSessionTrayView.swift`
- Modify: `MacIrlandTests/AppLaunchSupportTests.swift`
- Modify: `MacIrlandTests/UIDisplayFormattingTests.swift`

- [ ] **Step 1: Replace naive hover-to-panel with hover tray behavior**

Desired behavior:
- compact island stays small and non-blocking
- when multiple Claude Code sessions exist, pointer hover expands a lightweight tray similar to `vibe-irland-2.mp4`
- tray should show multi-session awareness without becoming a mini-panel

Requirements:
- use a small dwell delay to avoid accidental triggers
- cancel pending hover-open when pointer leaves early
- do not repeatedly reopen tray while it is already visible
- tray rows should remain compact and scannable

- [ ] **Step 2: Define hover routing**

Recommended routing:
- single-session compact island: hover may still open panel directly
- multi-session compact island: hover opens lightweight tray
- clicking a tray row opens panel focused to that session
- direct click on compact island can still open panel as a fallback

- [ ] **Step 3: Re-run focused tests**

Run:
```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter AppLaunchSupportTests
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter UIDisplayFormattingTests
```

---

## Task 6: Add Claude Code completion sound cue

**Files:**
- Modify: `MacIrlandApp/App/AppDelegate.swift`
- Modify: `MacIrlandApp/App/SoundCoordinator.swift`
- Modify: `MacIrlandKit/Core/State/TaskStateStore.swift`
- Modify: `MacIrlandKit/Core/Models/TaskModels.swift`
- Modify: `MacIrlandTests/TaskStateStoreTests.swift`
- Modify: `MacIrlandTests/AppLaunchSupportTests.swift`
- Create: `MacIrlandApp/Resources/Sounds/claude-complete-chiptune.wav`

- [ ] **Step 1: Wire a real completion cue path**

Use the existing `SoundMode` / `SoundCue.completed` model instead of inventing a second sound system.

Requirements:
- detect when a Claude Code session transitions into `.completed`
- play a short original retro/chiptune cue
- do not use copyrighted Mario audio directly
- avoid replaying the sound repeatedly on every refresh while the same session stays completed

- [ ] **Step 2: Respect current sound-mode semantics**

Default rule:
- `.all` plays the completion sound
- `.criticalOnly` does not play completion
- `.mute` plays nothing

Only change this if the current codebase already encodes a different consistent policy.

- [ ] **Step 3: Re-run focused tests**

Run:
```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter TaskStateStoreTests
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter AppLaunchSupportTests
```

---

## Task 7: Add running/completed icon feedback on island

**Files:**
- Modify: `MacIrlandKit/Features/Island/IslandPresentation.swift`
- Modify: `MacIrlandKit/Features/Island/IslandStatusStripView.swift`
- Modify: `MacIrlandKit/Features/Island/IslandExpandedCardView.swift`
- Modify: `MacIrlandKit/DesignSystem/PanelTheme.swift`
- Modify: `MacIrlandTests/UIDisplayFormattingTests.swift`

- [ ] **Step 1: Define icon state semantics**

User intent based on `macisland-run.png` + `vibe-irland-3.mp4`:
- when Claude Code is actively working, the corresponding island icon should animate and read as active
- when Claude Code is idle/ready, the icon should still have a lighter idle-state animation feel, following `vibe-irland-3.mp4`
- active state should feel green / working when appropriate, but the key requirement is distinct animated state language
- when work completes, completion sound plays once, then the icon stops animating and shifts to orange

Implementation requirements:
- `.running` should use an animated active state
- `.discovered` / `.recognizing` / ready-like idle state should use a subtler animated idle state
- `.completed` should use a static completed state
- animation style should be pixel/sprite-frame-like, not generic scale pulse
- the same icon state language should appear both in compact island and in multi-session tray rows
- do not animate blocking states forever unless current design already requires it
- keep the motion lightweight and non-distracting

- [ ] **Step 2: Implement lightweight icon motion**

Allowed direction:
- tiny pixel/sprite frame cycling inspired by `vibe-irland-3.mp4`
- optional subtle blink / bar-shift inside the glyph, as long as it reads like sprite animation

Not allowed:
- large-scale motion
- flashy particle effects
- motion that changes island size
- generic loader/spinner that loses the pixel-icon character

- [ ] **Step 3: Re-run focused tests**

Run:
```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter UIDisplayFormattingTests
```

---

## Task 8: Full verification and real runtime check

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Run full verification**

Run:
```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland"
swift build --package-path "/Users/lijunjie/Documents/AIproject/macirland"
```

- [ ] **Step 2: Do a real runtime scenario check**

Required real-world verification:

1. launch app
2. start first Claude Code session
3. while app is running, start a second Claude Code session
4. observe for at least `30-60s`

Success criteria:
- no crash
- compact island stays small
- alert does not force an expanded popup in the “still working” scenario
- 多 Claude Code 会话时，hover island 会展开轻量 tray
- tray row click 会打开 panel 并聚焦对应 session
- Claude Code task完成时会播放原创 chiptune 提示音（在 `SoundMode.all` 下）
- Claude Code 运行中图标会轻量动起来，并带绿色工作态
- Claude Code 待机/就绪时图标也有更轻的 idle 动效，风格参考 `vibe-irland-3.mp4`
- Claude Code 完成后图标停止运动并转为橙色

- [ ] **Step 3: Update docs**

Update `CLAUDE.md` with only the final, current behavior:
- compact island size strategy
- hover-to-panel behavior
- non-blocking alert policy
- concurrent-session crash fix status

- [ ] **Step 4: Write execution report**

Create:

Report must include:
1. objective recap
2. root cause summary
3. file changes
4. task execution details
5. verification matrix
6. deviations from plan
7. remaining risks

---

## Definition of Done

DoD:
- app no longer crashes when a second Claude Code session starts during runtime
- `1s` auto-refresh remains enabled
- compact island is visibly smaller and no longer blocks as much screen space
- alert no longer auto-expands into a large popup when work is still progressing
- multi-session hover opens a lightweight tray instead of jumping straight to the full panel
- Claude Code completed state plays an original retro/chiptune completion cue
- island icon now communicates running-vs-idle-vs-completed state through pixel-style motion + color
- `swift test` passes
- `swift build` passes
- `CLAUDE.md` updated
- execution report written to the fixed path
