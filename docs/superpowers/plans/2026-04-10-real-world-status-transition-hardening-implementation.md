# Real-World Status Transition Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修复真实 Claude Code 会话在“任务已结束、等待用户下一步指示”时仍被错误显示为 `running`，以及因此导致的图标/声音不切换问题。

**Architecture:** 当前产品的视觉、tray、panel、自动刷新和 readiness 主链路都已完成，但实机测试暴露出一个更关键的真实性问题：真实 Claude Code transcript 在任务完成后，经常不会命中现有的 `waitingInput / replyAvailable / completed` 识别规则，结果 session 继续停留在 `.running`。由于声音和图标都是基于状态跃迁触发的，这又连带导致“没有声音提示”和“图标不切换”。下一轮应聚焦真实 transcript 模式加固，而不是继续做新 UI。

**Tech Stack:** Swift, SwiftUI, AppKit, Observation, XCTest

---

## Inputs

### Must review first
- current status recognition in:
  - `MacIrlandKit/Services/Observation/ObservationService.swift`
  - `MacIrlandKit/Adapters/BuiltIn/BuiltInCLIAdapter.swift`
  - `MacIrlandKit/Services/Feedback/FeedbackService.swift`
  - `MacIrlandKit/Features/Icon/AnimatedStatusIcon.swift`

### Real-world issues to fix
- Claude task appears finished and awaiting user instruction, but MacIrland still shows `running`
- because status never transitions, waiting/completed sound cue never fires
- because status never transitions, icon also remains in running animation

---

## File Structure

### Modify
- `MacIrlandKit/Services/Observation/ObservationService.swift`
- `MacIrlandKit/Adapters/BuiltIn/BuiltInCLIAdapter.swift`
- `MacIrlandKit/Core/Models/TaskModels.swift`
- `MacIrlandKit/Services/Feedback/FeedbackService.swift`
- `MacIrlandKit/Features/Icon/AnimatedStatusIcon.swift`
- `MacIrlandKit/Features/Island/IslandPresentation.swift`
- `MacIrlandTests/TaskStateStoreTests.swift`
- `MacIrlandTests/UIDisplayFormattingTests.swift`
- `MacIrlandTests/AppLaunchSupportTests.swift`
- `CLAUDE.md`

### Create

---

## Task 1: Capture and encode real Claude end-of-turn transcript patterns

**Files:**
- Modify: `MacIrlandKit/Services/Observation/ObservationService.swift`
- Modify: `MacIrlandKit/Adapters/BuiltIn/BuiltInCLIAdapter.swift`
- Modify: `MacIrlandTests/TaskStateStoreTests.swift`

- [ ] **Step 1: Expand end-of-turn recognition beyond the current narrow keywords**

The current recognizer is too dependent on phrases like:
- `waiting for input`
- `please confirm`
- `task complete`
- `all set`

Add support for real Claude Code end-of-turn language patterns such as:
- implementation/reporting style completions followed by “if you want, I can…”
- explicit “let me know” / “tell me if you want” / “next step” style handoff phrasing
- completed-change summaries that imply work has finished even if the exact word `completed` is absent

Do not make the rules so broad that normal running prose becomes false completed/waiting states.

- [ ] **Step 2: Distinguish “awaiting user input” from “fully completed”**

Required behavior:
- if Claude has finished a unit of work but is now waiting for the user’s next instruction, prefer `waitingInput` or `replyAvailable`
- reserve `completed` for true terminal completion / done-for-now summaries

The goal is not just “stop saying running”, but “pick the right post-run status”.

- [ ] **Step 3: Keep observation-layer and adapter-layer logic aligned**

The status mapping in:
- `ClaudeStatusJudge`
- `BuiltInCLIAdapter`

must not drift.

If you improve recognition in one place, align the other place or refactor shared logic as needed.

- [ ] **Step 4: Add focused regression tests with realistic snippets**

Required coverage:
- realistic Claude “work finished, waiting for your next instruction” transcript becomes `waitingInput` or `replyAvailable`
- realistic Claude “done / wrapped up” transcript becomes `completed`
- ordinary ongoing narration still stays `running`
- recognition is consistent between observation and adapter layers

- [ ] **Step 5: Run focused verification**

Run:
```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter TaskStateStoreTests
```

---

## Task 2: Ensure post-run status transitions drive sound and icon changes

**Files:**
- Modify: `MacIrlandKit/Core/Models/TaskModels.swift`
- Modify: `MacIrlandKit/Services/Feedback/FeedbackService.swift`
- Modify: `MacIrlandKit/Features/Icon/AnimatedStatusIcon.swift`
- Modify: `MacIrlandKit/Features/Island/IslandPresentation.swift`
- Modify: `MacIrlandTests/UIDisplayFormattingTests.swift`
- Modify: `MacIrlandTests/AppLaunchSupportTests.swift`

- [ ] **Step 1: Verify status-to-icon semantics for post-run states**

Required semantics:
- `running` -> active green animation
- `waitingInput / replyAvailable` -> not the same as running; should visually read as “your turn / ready”
- `completed` -> completed visual treatment and no running animation

If current `animatedStatus` mapping collapses too many states into `.idle`, refine it enough so the user can tell the difference between “still running” and “waiting on you”.

- [ ] **Step 2: Verify status-to-sound semantics**

Required behavior:
- transition into `waitingInput / replyAvailable` should produce the waiting cue once
- transition into `completed` should produce the completion cue once
- once the session has left `running`, it must not keep behaving like a running task

- [ ] **Step 3: Add focused regression tests**

Required coverage:
- realistic running -> waiting transition emits waiting cue
- realistic running -> completed transition emits completion cue
- waiting/reply state maps to non-running visual semantics

- [ ] **Step 4: Run focused verification**

Run:
```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter UIDisplayFormattingTests
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter AppLaunchSupportTests
```

---

## Task 3: Perform explicit runtime walkthrough for the two reported issues

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Run full automated verification**

Run:
```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland"
swift build --package-path "/Users/lijunjie/Documents/AIproject/macirland"
```

- [ ] **Step 2: Perform real runtime walkthrough**

Required checks:

1. start a Claude Code task that is genuinely running -> island shows running state
2. let Claude finish and wait for next user instruction -> island/panel stop showing running and move to waiting-like state
3. verify the waiting/reply cue plays once on that transition
4. complete a task that should be treated as completed -> completion cue and completed visual state happen once

This runtime walkthrough is required. Do not mark the round complete based only on unit tests.

- [ ] **Step 3: Update docs**

Update `CLAUDE.md` to reflect only true behavior:
- real-world post-run Claude transcript recognition
- waiting/completed sound semantics
- post-run icon semantics

- [ ] **Step 4: Write execution report**

Create:

Report must include:
1. objective recap
2. root cause summary
3. file changes
4. task execution details
5. verification matrix
6. runtime walkthrough evidence
7. deviations from plan
8. remaining risks

---

## Definition of Done

DoD:
- real Claude post-run transcripts no longer remain stuck in `running`
- waiting-for-user and completed states are distinguished correctly
- sound cues fire once on the appropriate state transitions
- icon state stops looking “running” once the task has handed off to the user
- `swift test` passes
- `swift build` passes
- runtime walkthrough completed
- `CLAUDE.md` updated
- execution report written to the fixed path
