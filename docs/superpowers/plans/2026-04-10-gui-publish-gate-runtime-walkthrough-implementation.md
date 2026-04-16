# GUI Publish Gate Runtime Walkthrough Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在真实 macOS GUI 环境里完成发布前最后一轮运行验收，得到明确的 publish/no-publish 结论。

**Architecture:** 当前代码与测试已经达到可发布候选质量：`swift test`/`swift build` 全绿，Claude-first surface、自动刷新、tray、transition-based sound、guided onboarding 都已接上。阻塞发布的唯一核心问题已经不是代码层面，而是 GUI runtime evidence 缺失。下一轮不应继续扩功能，而应在真实 GUI 中完成一次完整 walkthrough，若发现问题就就地修复，并以结果决定是否发布。

**Tech Stack:** Swift, SwiftUI, AppKit, XCTest, AppleScript/UI scripting

---

## Inputs

### Must review first
- current manual findings from user:
  - task may still appear running after Claude has handed off
  - no sound/state switch was previously observed in real use

### Publish gate
This round must end with one explicit recommendation:
- ready to push and publish
- ready to push but not publish

No third vague answer.

---

## File Structure

### Modify
- `MacIrlandKit/Core/State/TaskStateStore.swift`
- `MacIrlandKit/Services/Observation/ObservationService.swift`
- `MacIrlandKit/Adapters/BuiltIn/BuiltInCLIAdapter.swift`
- `MacIrlandKit/Features/Icon/AnimatedStatusIcon.swift`
- `MacIrlandKit/Services/Feedback/FeedbackService.swift`
- `MacIrlandKit/Features/Panel/PanelView.swift`
- `MacIrlandTests/TaskStateStoreTests.swift`
- `MacIrlandTests/UIDisplayFormattingTests.swift`
- `MacIrlandTests/AppLaunchSupportTests.swift`
- `CLAUDE.md`

### Create

---

## Task 1: Run the full GUI walkthrough and capture evidence

**Files:**

- [ ] **Step 1: Start the actual dev app**

Use the supported launch path:
```bash
cd /Users/lijunjie/Documents/AIproject/macirland
./Scripts/run-dev-app.sh
```

- [ ] **Step 2: Walk the required runtime scenarios**

These scenarios are mandatory and must be actually executed:

1. one Claude Code session starts -> compact island shows running
2. Claude finishes and waits for user -> island/panel leave running state
3. waiting/reply cue plays exactly once
4. completed task -> completed visual state and completion cue
5. close all Claude sessions -> no-session readiness appears
6. open two Claude sessions -> tray appears and row click routes correctly

- [ ] **Step 3: Capture concrete evidence**

For each scenario, record evidence in the execution report:
- what was done
- what was observed
- whether it matched expectation

Screenshots are recommended if available in the environment, but at minimum the report must contain specific observed results, not generic “verified”.

---

## Task 2: Fix any GUI-runtime-only failures discovered in Task 1

**Files:**
- Modify whichever runtime files are actually implicated
- Modify tests that encode the discovered regression

- [ ] **Step 1: If all scenarios pass, make no unnecessary code changes**

Do not invent a fix round if the walkthrough is actually green.

- [ ] **Step 2: If any scenario fails, fix only that concrete issue**

Examples of acceptable targets:
- stale session cleanup still lags in real runtime
- waiting/completed transcript not recognized in real output
- sound cue path not firing in GUI despite tests
- icon state still reads as running after handoff
- tray hover or row routing broken in real UI

- [ ] **Step 3: Add regression coverage for the discovered issue**

Any runtime bug found and fixed must get at least one automated regression test where feasible.

- [ ] **Step 4: Re-run the specific runtime scenario**

Do not rely only on unit tests after the fix. Re-run the failing GUI scenario and document the new result.

---

## Task 3: Final automated verification and publish recommendation

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Run full automated verification**

Run:
```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland"
swift build --package-path "/Users/lijunjie/Documents/AIproject/macirland"
```

- [ ] **Step 2: Update docs only with runtime-verified truths**

If this walkthrough proves a behavior, reflect it in `CLAUDE.md`.
If a behavior is still uncertain, do not overstate it.

- [ ] **Step 3: Write an explicit release recommendation**

The execution report must end with exactly one of:
- `ready to push and publish`
- `ready to push but not publish`

and list the concrete reasons.

- [ ] **Step 4: Include a push recommendation**

Also state whether it is safe to push the current branch to GitHub now.

---

## Definition of Done

DoD:
- all 6 GUI runtime scenarios are actually walked through
- any discovered GUI-only runtime failures are either fixed or explicitly recorded as blockers
- `swift test` passes
- `swift build` passes
- execution report includes concrete runtime evidence
- execution report includes explicit publish recommendation
- execution report includes explicit push recommendation
- `CLAUDE.md` updated only with verified behavior
