# Release Candidate Runtime Acceptance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在准备推送和发布前，完成最后一轮真实运行验收，修掉仍会阻止“实际可用/可发布”的 runtime 问题。

**Architecture:** 当前代码和测试已经非常完整，`swift test`/`swift build` 都是绿的，Claude-first surface、tray、自动刷新、transition-based sound、guided onboarding 也都已经接上。现在剩余的不确定性几乎全部来自真实运行环境：真实 Claude 会话结束时状态是否正确切换、声音和图标是否真实变化、关闭会话后 stale sessions 是否被清理、hover tray 是否在真实 UI 里可靠出现。这一轮不再扩新功能，专注于 real runtime acceptance，发现的问题就地修复，并以真实 walkthrough 结果作为是否可发布的准绳。

**Tech Stack:** Swift, SwiftUI, AppKit, Observation, XCTest, AppleScript/UI scripting

---

## Inputs

### Must review first
- current real-world findings from manual checks:
  - task may still appear as running after Claude has handed off
  - sound / icon transition has not yet been proven in real runtime
  - stale session cleanup after closing Claude/Terminal was previously observed

### Release decision gate
This round is specifically for answering:
- can we push?
- can we publish?

The answer must be based on real runtime evidence, not just unit tests.

---

## File Structure

### Modify
- `MacIrlandKit/Core/State/TaskStateStore.swift`
- `MacIrlandKit/Services/Observation/ObservationService.swift`
- `MacIrlandKit/Adapters/BuiltIn/BuiltInCLIAdapter.swift`
- `MacIrlandApp/App/IslandCoordinator.swift`
- `MacIrlandKit/Features/Icon/AnimatedStatusIcon.swift`
- `MacIrlandKit/Services/Feedback/FeedbackService.swift`
- `MacIrlandTests/TaskStateStoreTests.swift`
- `MacIrlandTests/AppLaunchSupportTests.swift`
- `MacIrlandTests/UIDisplayFormattingTests.swift`
- `CLAUDE.md`

### Create

---

## Task 1: Reproduce and fix stale session teardown in real runtime

**Files:**
- Modify: `MacIrlandKit/Core/State/TaskStateStore.swift`
- Modify: `MacIrlandKit/Services/Observation/ObservationService.swift`
- Modify: `MacIrlandKit/Adapters/BuiltIn/BuiltInCLIAdapter.swift`
- Modify: `MacIrlandTests/TaskStateStoreTests.swift`

- [ ] **Step 1: Reproduce stale-session persistence with a deterministic test or fixture**

Capture the real behavior seen in manual testing:
- close Terminal / Claude session
- observation no longer yields a live Claude event
- MacIrland should stop showing the old session

If the current logic intentionally preserves old sessions through `mergeHistory` or snapshot gaps, identify that explicitly.

- [ ] **Step 2: Fix teardown semantics without breaking history preservation**

Requirements:
- dead/stale live sessions must not continue occupying the primary runtime surface
- session history may still be preserved if that is part of the product model
- but the current “live task” UI must stop treating them as active

- [ ] **Step 3: Add focused regression tests**

Required coverage:
- closed/disappeared Claude session no longer remains active
- no-session readiness can actually surface after teardown
- history preservation does not keep stale session in active runtime list

- [ ] **Step 4: Run focused verification**

Run:
```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter TaskStateStoreTests
```

---

## Task 2: Prove real post-run state transitions drive the visible UX

**Files:**
- Modify: `MacIrlandKit/Services/Observation/ObservationService.swift`
- Modify: `MacIrlandKit/Adapters/BuiltIn/BuiltInCLIAdapter.swift`
- Modify: `MacIrlandKit/Features/Icon/AnimatedStatusIcon.swift`
- Modify: `MacIrlandKit/Services/Feedback/FeedbackService.swift`
- Modify: `MacIrlandTests/TaskStateStoreTests.swift`
- Modify: `MacIrlandTests/UIDisplayFormattingTests.swift`

- [ ] **Step 1: Validate real end-of-turn snippets against current rules**

Do not assume the previous round is sufficient.

Use real or realistic transcript snippets that correspond to:
- still running
- handoff / waiting for user
- fully completed

Check whether the actual current rules map them correctly.

- [ ] **Step 2: Fix any remaining mismatch between state, icon, and sound**

Required visible behavior:
- running -> running animation
- waiting/reply -> no longer looks like running
- completed -> completed visual treatment
- waiting/completed transitions -> sound fires once

If `idle` is currently too ambiguous for post-run handoff, fix that.

- [ ] **Step 3: Add focused regression tests**

Required coverage:
- post-run handoff no longer renders as running
- completion no longer renders as running
- transition sound triggers remain once-only

- [ ] **Step 4: Run focused verification**

Run:
```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter TaskStateStoreTests
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter UIDisplayFormattingTests
```

---

## Task 3: Perform full runtime acceptance walkthrough

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Run full automated verification**

Run:
```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland"
swift build --package-path "/Users/lijunjie/Documents/AIproject/macirland"
```

- [ ] **Step 2: Run required manual/runtime acceptance checks**

These checks are mandatory:

1. start one real Claude Code session and confirm compact island enters running state
2. let Claude finish and hand back to the user; confirm island/panel leave running state
3. confirm waiting/reply sound plays exactly once on handoff
4. complete a task; confirm completed visual state and completion cue
5. close all Claude/Terminal sessions opened for the test; confirm no-session or idle readiness state appears
6. open two Claude sessions; confirm tray appears and still routes correctly

Do not mark the round complete if these checks are not actually performed.

- [ ] **Step 3: Write release recommendation**

The execution report must explicitly state one of:
- ready to push and publish
- ready to push but not publish
- not ready to push

with reasons tied to runtime evidence.

- [ ] **Step 4: Update docs**

Update `CLAUDE.md` only with behavior that was both implemented and runtime-verified.

- [ ] **Step 5: Write execution report**

Create:

Report must include:
1. objective recap
2. runtime issues found
3. file changes
4. task execution details
5. verification matrix
6. runtime walkthrough evidence
7. release recommendation
8. deviations from plan
9. remaining risks

---

## Definition of Done

DoD:
- stale Claude sessions are not left active after teardown
- no-session readiness can appear in real runtime
- post-run waiting/completed states visibly leave running mode
- sound cues are confirmed in real runtime
- `swift test` passes
- `swift build` passes
- runtime acceptance walkthrough completed
- execution report includes an explicit release recommendation
- `CLAUDE.md` updated
