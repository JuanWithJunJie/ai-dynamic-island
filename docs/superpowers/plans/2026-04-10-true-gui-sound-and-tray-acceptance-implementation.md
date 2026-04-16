# True GUI Sound And Tray Acceptance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 完成最后两项真实 GUI 发布阻塞验证：真实声音提示播放、真实多 Claude Code session tray 行为；只有这两项真实通过后，才可宣布 ready to publish。

**Architecture:** 当前代码和自动化测试已经很强，但 `final-manual-publish-gate` 报告里把“unit test 逻辑正确”替代成了“发布可用”，这在声音和 tray 上不够严谨。下一轮不做任何新功能，只在真实 macOS GUI 环境中跑通声音和多会话 tray，并且如果 GUI 暴露 bug 就地修复。

**Tech Stack:** Swift, SwiftUI, AppKit, XCTest, macOS GUI automation

---

## Inputs

### Must review first
- current code in:
  - `MacIrlandApp/App/RefreshCoordinator.swift`
  - `MacIrlandKit/Services/Feedback/FeedbackService.swift`
  - `MacIrlandKit/Services/Feedback/ChiptuneSoundPlayer.swift`
  - `MacIrlandKit/Core/State/TaskStateStore.swift`
  - `MacIrlandKit/Features/Island/IslandMultiSessionTrayView.swift`
  - `MacIrlandApp/App/IslandCoordinator.swift`

### Current blockers to clear
- 声音 cue 只做了逻辑验证，未完成真实 GUI 播放验收
- tray 只做了逻辑验证，未完成真实两个 Claude Code session 的 GUI 验收

---

## File Structure

### Modify
- only files required by real GUI bugs found during walkthrough
- `CLAUDE.md` (only if a runtime-verified truth changes)

### Create

---

## Task 1: Verify real GUI sound playback

**Files:**
- Modify only if bug found during walkthrough

- [ ] **Step 1: Launch the dev app in a real GUI context**

Use the normal dev app path, not bare CLI binary execution.

- [ ] **Step 2: Drive a real Claude session through a waiting/reply transition**

Required outcome:
- when Claude hands control back to the user, a waiting/reply cue is actually audible in the macOS GUI environment

If not audible:
- determine whether the issue is status transition, sound mode, audio engine startup, or playback timing
- fix only the actual root cause

- [ ] **Step 3: Drive a real Claude session through a completed transition**

Required outcome:
- when Claude reaches a completed state, the completion cue is actually audible once

If not audible:
- fix the real root cause, not just the symptom

- [ ] **Step 4: Add regression coverage only if code changed**

If a bug was fixed, add/update the smallest tests that protect it.

---

## Task 2: Verify real GUI multi-session tray behavior

**Files:**
- Modify only if bug found during walkthrough

- [ ] **Step 1: Create two simultaneously recognized Claude Code sessions**

Do not substitute this with unit tests.

Required outcome:
- both sessions are genuinely recognized by MacIrland in the real GUI environment

- [ ] **Step 2: Verify tray appears and is visually usable**

Required outcome:
- compact island transitions into tray when appropriate
- tray rows render correctly for the two real sessions

- [ ] **Step 3: Verify tray row click routing**

Required outcome:
- clicking a tray row opens/focuses panel on the intended session

- [ ] **Step 4: Add regression coverage only if code changed**

If GUI walkthrough exposed a real bug and code changed, add/update the smallest tests that protect it.

---

## Task 3: Final publish decision

**Files:**
- Modify: `CLAUDE.md` only if runtime-verified truth changes

- [ ] **Step 1: Run full verification if code changed**

Run:
```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland"
swift build --package-path "/Users/lijunjie/Documents/AIproject/macirland"
```

- [ ] **Step 2: Write the execution report**

Create:

The report must include:
1. objective recap
2. GUI scenarios executed
3. observed results
4. file changes
5. verification matrix
6. runtime evidence
7. push recommendation
8. publish recommendation
9. remaining risks

- [ ] **Step 3: Make an explicit final call**

The report must end with one of:
- `ready to push and publish`
- `ready to push but not publish`

Do not use unit-test substitution as the sole basis for publish approval.

---

## Definition of Done

DoD:
- waiting/reply cue has been heard in the real GUI environment
- completed cue has been heard in the real GUI environment
- two real Claude Code sessions have been observed in tray in the GUI
- tray row click routing has been verified in the GUI
- any discovered GUI bug has been fixed and regression-covered
- final report gives an explicit publish recommendation based on real GUI evidence
