# Feedback And Tray Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 收口上一轮 Reference Video Alignment 的剩余问题，重点修复声音重复触发、tray 触发语义过粗，以及 alert 的轻提示表达，让产品从“测试通过”进一步走向“日常使用更稳”。

**Architecture:** 当前代码已经具备基础参考视频形态：compact island、hover tray、图标状态语言、完成提示音都已接上，且全量测试为绿。但执行报告也清楚指出两个残留风险：`FeedbackService` 仍按“当前是否存在 completed/running/waiting”等状态发声，而不是按“状态跃迁”发声；`hasMultipleRelevantSessions` 目前本质仍是 `sessions.count > 1`。此外，`.alert` 虽然已经不再错误自动放大，但在 compact/tray 中还缺少更清晰又不过度打断的轻提示。下一轮应聚焦这些收口项，不再扩新交互层。

**Tech Stack:** Swift, SwiftUI, AppKit, Observation, XCTest

---

## Inputs

### Must review first
- `docs/superpowers/plans/2026-04-10-reference-video-alignment-implementation.md`
- `example/vibe-irland-2.mp4`
- `example/vibe-irland-3.mp4`

### Remaining issues from previous report
- completion / running / waiting sound cues may replay on every refresh, because cues are derived from current state presence instead of state transitions
- `hasMultipleRelevantSessions` is still effectively `sessions.count > 1`
- alert no longer over-expands, but compact/tray-level lightweight signaling can still be improved
- previous report lacked strong real runtime verification detail

---

## File Structure

### Modify
- `MacIrlandApp/App/RefreshCoordinator.swift`
- `MacIrlandKit/Services/Feedback/FeedbackService.swift`
- `MacIrlandKit/Core/State/TaskStateStore.swift`
- `MacIrlandKit/Features/Island/IslandPresentation.swift`
- `MacIrlandKit/Features/Island/IslandStatusStripView.swift`
- `MacIrlandKit/Features/Island/IslandMultiSessionTrayView.swift`
- `MacIrlandTests/TaskStateStoreTests.swift`
- `MacIrlandTests/UIDisplayFormattingTests.swift`
- `MacIrlandTests/AppLaunchSupportTests.swift`
- `CLAUDE.md`

### Create

---

## Task 1: Make sound cues transition-aware instead of presence-aware

**Files:**
- Modify: `MacIrlandApp/App/RefreshCoordinator.swift`
- Modify: `MacIrlandKit/Services/Feedback/FeedbackService.swift`
- Modify: `MacIrlandTests/TaskStateStoreTests.swift`
- Modify: `MacIrlandTests/AppLaunchSupportTests.swift`

- [ ] **Step 1: Introduce previous-vs-current session comparison**

Replace the current “if any session is completed/running/waiting/failed, emit cue” approach with transition-aware cue generation.

Required behavior:
- only emit `.completed` when a session transitions into `.completed`
- only emit `.taskStarted` when a session transitions into active running
- only emit `.waitingForReply` when a session newly enters waiting/reply state
- avoid replaying the same cue every 1-second refresh while state is unchanged

- [ ] **Step 2: Preserve current sound-mode gating**

Do not redesign sound settings in this round.

Keep current `SoundMode` behavior unless a test proves it is internally inconsistent.

- [ ] **Step 3: Add focused regression tests**

Required coverage:
- completed sound plays once on transition, not repeatedly
- waiting sound plays once on entering waiting/reply state
- unchanged running state does not re-trigger start sound every refresh

- [ ] **Step 4: Run focused tests**

Run:
```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter TaskStateStoreTests
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter AppLaunchSupportTests
```

---

## Task 2: Replace coarse tray eligibility with relevant-session semantics

**Files:**
- Modify: `MacIrlandKit/Core/State/TaskStateStore.swift`
- Modify: `MacIrlandApp/App/IslandCoordinator.swift`
- Modify: `MacIrlandTests/TaskStateStoreTests.swift`
- Modify: `MacIrlandTests/AppLaunchSupportTests.swift`

- [ ] **Step 1: Define “relevant multi-session” explicitly**

Do not leave:
```swift
hasMultipleRelevantSessions = sessions.count > 1
```

Replace it with a clearer rule that prefers:
- multiple relevant Claude Code sessions first
- optionally other CLI sessions only when they truly belong in the same top-level tray experience

The resulting behavior should be closer to the reference video than generic multi-CLI counting.

- [ ] **Step 2: Keep tray routing behavior stable**

Requirements:
- single relevant session → hover can keep direct panel behavior
- multiple relevant sessions → hover opens tray
- tray still remains lightweight and session-row-driven

- [ ] **Step 3: Add focused tests**

Required coverage:
- multiple Claude Code sessions → tray eligible
- one Claude Code + unrelated/low-value case → tray not spuriously eligible
- eligibility remains stable across refresh

- [ ] **Step 4: Run focused tests**

Run:
```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter TaskStateStoreTests
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter AppLaunchSupportTests
```

---

## Task 3: Improve lightweight alert signaling without reintroducing interruption

**Files:**
- Modify: `MacIrlandKit/Features/Island/IslandPresentation.swift`
- Modify: `MacIrlandKit/Features/Island/IslandStatusStripView.swift`
- Modify: `MacIrlandKit/Features/Island/IslandMultiSessionTrayView.swift`
- Modify: `MacIrlandTests/UIDisplayFormattingTests.swift`

- [ ] **Step 1: Strengthen compact/tray-level alert visibility**

Target:
- alert should remain easy to notice
- but should still not auto-expand into the large highlighted card while work is progressing

Allowed directions:
- stronger secondary text
- subtle row/chip tint change
- clearer compact copy for alert focus

Not allowed:
- reintroducing aggressive popup behavior
- making compact island visually noisy

- [ ] **Step 2: Keep consistency across compact and tray**

If alert is softly emphasized in compact, tray rows should reflect the same semantic distinction.

- [ ] **Step 3: Run focused tests**

Run:
```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter UIDisplayFormattingTests
```

---

## Task 4: Real runtime verification and closure

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Run full verification**

Run:
```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland"
swift build --package-path "/Users/lijunjie/Documents/AIproject/macirland"
```

- [ ] **Step 2: Run explicit runtime checks**

Required manual/runtime checks:

1. keep a running Claude Code session alive for multiple refresh ticks
2. verify running cue does not replay continuously
3. complete a task and verify completion sound fires once
4. keep multiple relevant Claude Code sessions open and verify tray eligibility matches expectation
5. confirm alert remains visible without over-expansion

- [ ] **Step 3: Update docs**

Update `CLAUDE.md` with only currently true behavior:
- transition-based sound cue semantics
- semantic tray trigger rule
- compact/tray alert signaling summary

- [ ] **Step 4: Write execution report**

Create:

Report must include:
1. objective recap
2. previous risks addressed
3. file changes
4. task execution details
5. verification matrix
6. deviations from plan
7. remaining risks

---

## Definition of Done

DoD:
- sound cues are transition-based, not replayed every refresh
- tray eligibility is no longer a plain `sessions.count > 1`
- alert remains softly visible without large interruption
- `swift test` passes
- `swift build` passes
- `CLAUDE.md` updated
- execution report written to the fixed path
