# Real Claude Completion And Cue Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修复真实 Claude Code 会话在任务执行完毕后仍显示 `运行中`，且没有播放等待/完成提示音的问题。

**Architecture:** 当前自动刷新、Claude-first surface、transition-based feedback 链路都已存在，问题集中在“真实 Claude transcript 结束态识别仍不稳定”。这一轮不做新 UI，而是把真实完成态/交还控制权的 transcript 模式识别准，并确保状态跃迁能自然驱动图标与声音。先用真实运行证据反推输入，再补回归测试，最后做真实 GUI walkthrough。

**Tech Stack:** Swift, SwiftUI, AppKit, XCTest, AppleScript-based terminal observation

---

## Inputs

### Must review first
- 用户最新实测反馈：
  - Claude Code 任务执行完毕后，对应 session 仍显示 `运行中`
  - 没有声音提示
- 当前关键文件：
  - `/Users/lijunjie/Documents/AIproject/macirland/MacIrlandKit/Services/Observation/ObservationService.swift`
  - `/Users/lijunjie/Documents/AIproject/macirland/MacIrlandKit/Adapters/BuiltIn/BuiltInCLIAdapter.swift`
  - `/Users/lijunjie/Documents/AIproject/macirland/MacIrlandKit/Services/Feedback/FeedbackService.swift`
  - `/Users/lijunjie/Documents/AIproject/macirland/MacIrlandKit/Features/Icon/AnimatedStatusIcon.swift`
  - `/Users/lijunjie/Documents/AIproject/macirland/MacIrlandKit/Features/Diagnostics/DiagnosticsSectionView.swift`

### Real bug to fix
- 真实 Claude Code 会话结束并等待用户下一步时，panel / island / session row 仍显示 `运行中`
- 因为状态没有从 `running` 跃迁到 `waitingInput / replyAvailable / completed`，所以 cue 不会播放
- 当前已有 normalized transcript，但还没有证明它覆盖了真实 Claude 结束态的主要输出模式

---

## File Structure

### Modify
- `/Users/lijunjie/Documents/AIproject/macirland/MacIrlandKit/Services/Observation/ObservationService.swift`
- `/Users/lijunjie/Documents/AIproject/macirland/MacIrlandKit/Adapters/BuiltIn/BuiltInCLIAdapter.swift`
- `/Users/lijunjie/Documents/AIproject/macirland/MacIrlandKit/Services/Feedback/FeedbackService.swift` (only if transition path still needs correction)
- `/Users/lijunjie/Documents/AIproject/macirland/MacIrlandKit/Features/Icon/AnimatedStatusIcon.swift` (only if waiting/completed visual semantics still need tightening)
- `/Users/lijunjie/Documents/AIproject/macirland/MacIrlandKit/Features/Diagnostics/DiagnosticsSectionView.swift`
- `/Users/lijunjie/Documents/AIproject/macirland/MacIrlandTests/TaskStateStoreTests.swift`
- `/Users/lijunjie/Documents/AIproject/macirland/MacIrlandTests/UIDisplayFormattingTests.swift` (only if visual semantics change)
- `/Users/lijunjie/Documents/AIproject/macirland/CLAUDE.md`

### Create

---

## Task 1: Reproduce the real failure with actual transcript evidence

**Files:**
- Modify: `/Users/lijunjie/Documents/AIproject/macirland/MacIrlandTests/TaskStateStoreTests.swift`
- Modify: `/Users/lijunjie/Documents/AIproject/macirland/MacIrlandKit/Features/Diagnostics/DiagnosticsSectionView.swift` (only if more debug output is needed)

- [ ] **Step 1: Capture the exact failing transcript shape from the real app**

Required evidence to gather from a real affected session:
- raw preview
- normalized preview
- inferred status
- decision reason

Do not start by guessing more phrases. First determine what the app is actually seeing when the user says “Claude 已经结束但还是 running”.

- [ ] **Step 2: Add failing regression tests that mirror the real failing transcript**

Required coverage:
- one realistic raw transcript for “任务完成并交还控制权，但当前仍会被误判成 running”
- one realistic raw transcript for “任务完成，应该进入 completed”
- one realistic raw transcript for “仍在执行中，应该保持 running”

The failing tests must be based on the actual captured transcript shape, not synthetic placeholder prose.

- [ ] **Step 3: Run the focused failing tests**

Run:
```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter TaskStateStoreTests
```

Expected:
- the new real-world completion/handoff regression tests fail before the fix

---

## Task 2: Harden end-state recognition for real Claude completion/handoff output

**Files:**
- Modify: `/Users/lijunjie/Documents/AIproject/macirland/MacIrlandKit/Services/Observation/ObservationService.swift`
- Modify: `/Users/lijunjie/Documents/AIproject/macirland/MacIrlandKit/Adapters/BuiltIn/BuiltInCLIAdapter.swift`
- Modify: `/Users/lijunjie/Documents/AIproject/macirland/MacIrlandTests/TaskStateStoreTests.swift`

- [ ] **Step 1: Fix recognition at the root-cause layer**

Prefer one of these root-cause fixes, based on the captured evidence:
- improve normalized tail extraction so the newest meaningful lines dominate
- strip additional Claude TUI noise that still pollutes the tail
- refine the handoff/completion signal sets against the real transcript
- distinguish “still working” from “prompt returned / over to user” more reliably

Do not paper over the issue by forcing sound triggers without state change.

- [ ] **Step 2: Keep observation and adapter semantics aligned**

`ObservationService` and `BuiltInCLIAdapter` must not drift.

Required outcome:
- the same real transcript shape yields the same status in both paths
- no case where observation says waiting/completed but adapter still says running

- [ ] **Step 3: Re-run focused tests**

Run:
```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter TaskStateStoreTests
```

Expected:
- all focused tests pass, including the new real-world regression cases

---

## Task 3: Ensure corrected state transitions actually drive sound and visual changes

**Files:**
- Modify only if needed:
  - `/Users/lijunjie/Documents/AIproject/macirland/MacIrlandKit/Services/Feedback/FeedbackService.swift`
  - `/Users/lijunjie/Documents/AIproject/macirland/MacIrlandKit/Features/Icon/AnimatedStatusIcon.swift`
  - `/Users/lijunjie/Documents/AIproject/macirland/MacIrlandTests/TaskStateStoreTests.swift`
  - `/Users/lijunjie/Documents/AIproject/macirland/MacIrlandTests/UIDisplayFormattingTests.swift`

- [ ] **Step 1: Verify transition-based cue emission from corrected states**

Required outcomes:
- `running -> waitingInput/replyAvailable` emits waiting cue once
- `running -> completed` emits completed cue once
- repeated refresh while status stays unchanged does not replay the same cue

- [ ] **Step 2: Verify post-run visual semantics**

Required outcomes:
- post-run waiting/reply no longer uses running animation
- completed no longer uses running animation
- waiting/reply and truly idle remain visually distinguishable

- [ ] **Step 3: Add regression tests only where behavior changed**

Do not churn tests unnecessarily if existing tests already cover the corrected transition path.

---

## Task 4: Real GUI walkthrough against the exact user complaint

**Files:**
- Modify: `/Users/lijunjie/Documents/AIproject/macirland/CLAUDE.md` only if runtime truth changes

- [ ] **Step 1: Run full automated verification**

Run:
```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland"
swift build --package-path "/Users/lijunjie/Documents/AIproject/macirland"
```

- [ ] **Step 2: Perform a true GUI runtime walkthrough**

Required walkthrough:
1. launch the dev app
2. run a real Claude Code task
3. let the task finish and wait for the user
4. confirm the corresponding session no longer says `运行中`
5. confirm the icon no longer shows running animation
6. confirm a waiting/reply or completed cue plays once
7. verify diagnostics show raw preview, normalized preview, and a reason that matches the classification

This walkthrough is mandatory. Do not replace it with unit tests.

- [ ] **Step 3: Update docs**

Only update `/Users/lijunjie/Documents/AIproject/macirland/CLAUDE.md` with truths actually verified in runtime.

- [ ] **Step 4: Write execution report**

Create:

The report must include:
1. objective recap
2. real failing transcript shape
3. root cause summary
4. file changes
5. task execution details
6. verification matrix
7. runtime walkthrough evidence
8. deviations from plan
9. remaining risks
10. publish recommendation

---

## Definition of Done

DoD:
- the exact real complaint is no longer reproducible
- a real Claude Code task that has finished and yielded control no longer displays `运行中`
- waiting/reply or completed status becomes visible in GUI
- the corresponding cue plays once on the real transition
- diagnostics can explain the classification using raw + normalized preview
- `swift test` passes
- `swift build` passes
- execution report is written to the fixed path
