# Real Terminal Transcript Normalization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修复真实 Claude Code 会话在任务结束后仍被长期显示为 `运行中`、没有等待/完成提示音的问题，重点解决“真实终端 transcript 在进入状态判断前未被充分清洗，导致 end-state 识别失败”。

**Architecture:** 当前状态机、图标和声音主链路已经存在，问题更像是输入质量问题：`ObservationService` 直接拿 Terminal/iTerm 的原始 `contents` 做 `ClaudeStatusJudge`，而真实 Claude TUI 输出里混有 prompt、边框、状态栏、控制字符、旧轮次内容和窗口噪声。只靠继续加关键词会越来越脆。下一轮应先建立 transcript normalization / tail extraction，再让 `ClaudeStatusJudge` 和 `BuiltInCLIAdapter` 基于更稳定的文本做判定，并补一轮真实 runtime walkthrough。

**Tech Stack:** Swift, SwiftUI, AppKit, Observation, XCTest, AppleScript-based terminal observation

---

## Inputs

### Must review first
- user-reported screenshot showing all sessions still as running
- current code in:
  - `MacIrlandKit/Services/Observation/ObservationService.swift`
  - `MacIrlandKit/Adapters/BuiltIn/BuiltInCLIAdapter.swift`
  - `MacIrlandKit/Core/State/TaskStateStore.swift`
  - `MacIrlandKit/Features/Icon/AnimatedStatusIcon.swift`
  - `MacIrlandKit/Features/Diagnostics/DiagnosticsSectionView.swift`

### Real bug to fix
- Claude Code 已结束并在等用户下一步，但 compact island / panel / session rows 仍然显示 `运行中`
- 因为状态没有从 `running` 跃迁出去，所以 waiting/completed cue 也不会触发
- 当前问题在真实 GUI 中已复现，不接受“测试逻辑正确”作为替代

---

## File Structure

### Modify
- `MacIrlandKit/Services/Observation/ObservationService.swift`
- `MacIrlandKit/Adapters/BuiltIn/BuiltInCLIAdapter.swift`
- `MacIrlandKit/Core/Models/TaskModels.swift`
- `MacIrlandKit/Features/Diagnostics/DiagnosticsSectionView.swift`
- `MacIrlandTests/TaskStateStoreTests.swift`
- `MacIrlandTests/UIDisplayFormattingTests.swift`
- `CLAUDE.md`

### Create

---

## Task 1: Make the real transcript observable and debuggable

**Files:**
- Modify: `MacIrlandKit/Services/Observation/ObservationService.swift`
- Modify: `MacIrlandKit/Core/Models/TaskModels.swift`
- Modify: `MacIrlandKit/Features/Diagnostics/DiagnosticsSectionView.swift`
- Modify: `MacIrlandTests/TaskStateStoreTests.swift`

- [ ] **Step 1: Introduce a normalized transcript preview for diagnostics**

Current diagnostics mostly expose raw preview text, which is not enough to debug why a real Claude session still resolves to `running`.

Required behavior:
- keep the raw preview for forensic reference
- also expose a normalized/cleaned preview that shows what the judge actually sees

This must make it obvious whether the problem is:
- transcript never contained the end-state text
- transcript contained it but buried in noise
- transcript was cleaned incorrectly

- [ ] **Step 2: Keep the normalization step in one place**

Do not scatter ad-hoc `replacingOccurrences` throughout multiple callers.

Create a single normalization flow in observation/judging path that:
- strips ANSI/control noise if present
- normalizes whitespace
- preserves meaningful Chinese and English text
- prefers the most recent tail of the transcript, not stale earlier output

- [ ] **Step 3: Add diagnostics-focused tests**

Required coverage:
- normalization removes terminal noise but preserves meaningful handoff text
- diagnostics can show both raw and normalized preview without losing context

- [ ] **Step 4: Run focused verification**

Run:
```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter TaskStateStoreTests
```

---

## Task 2: Rebuild Claude end-state recognition on top of normalized transcript

**Files:**
- Modify: `MacIrlandKit/Services/Observation/ObservationService.swift`
- Modify: `MacIrlandKit/Adapters/BuiltIn/BuiltInCLIAdapter.swift`
- Modify: `MacIrlandTests/TaskStateStoreTests.swift`

- [ ] **Step 1: Base `ClaudeStatusJudge` on normalized tail text**

Do not continue judging directly on raw `contents of eachTab/session`.

Required behavior:
- judge should consume normalized tail text
- stale earlier transcript content should not dominate over the latest handoff/completion lines

- [ ] **Step 2: Add the real post-run patterns that are still missing**

Based on the user screenshot and current real behavior, cover patterns like:
- concise “done, now over to you” prompts
- Chinese Q&A handoff wording
- terminal-ready prompt situations where Claude has clearly yielded control

Do not just append random keywords; encode them against the normalized text.

- [ ] **Step 3: Keep adapter and observation semantics aligned**

`BuiltInCLIAdapter` must either reuse the same normalized judging path or stay tightly aligned with it.

No more silent drift where one path says waiting and another says running.

- [ ] **Step 4: Add regression tests for the exact real bug class**

Required coverage:
- realistic raw transcript with prompt noise still becomes `waitingInput` after normalization
- realistic raw transcript with completed summary still becomes `completed`
- noisy running transcript still remains `running`
- adapter and observation agree

- [ ] **Step 5: Run focused verification**

Run:
```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter TaskStateStoreTests
```

---

## Task 3: Re-verify state-driven icon and sound behavior

**Files:**
- Modify only if the walkthrough shows a remaining bug:
  - `MacIrlandKit/Features/Icon/AnimatedStatusIcon.swift`
  - `MacIrlandKit/Services/Feedback/FeedbackService.swift`
  - `MacIrlandTests/UIDisplayFormattingTests.swift`

- [ ] **Step 1: Verify that corrected status transitions now drive waiting/completed visuals**

Required outcome:
- once transcript is recognized as waiting/reply, icon must stop looking like `running`
- once transcript is recognized as completed, icon must show completed semantics

- [ ] **Step 2: Verify that corrected status transitions now drive cue emission**

Required outcome:
- running -> waitingInput/replyAvailable emits waiting cue once
- running -> completed emits completed cue once

Only fix code here if the improved recognition still does not propagate correctly.

- [ ] **Step 3: Add regression coverage only if code changed**

If no visual/feedback code changed, do not churn tests unnecessarily.

---

## Task 4: Real GUI walkthrough against the user-reported bug

**Files:**
- Modify: `CLAUDE.md` only if runtime-verified truth changes

- [ ] **Step 1: Run full automated verification**

Run:
```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland"
swift build --package-path "/Users/lijunjie/Documents/AIproject/macirland"
```

- [ ] **Step 2: Reproduce the real bug in GUI and verify the fix**

Required walkthrough:
1. launch app
2. run a real Claude Code task
3. let Claude finish and wait for the user
4. confirm the corresponding session no longer displays `运行中`
5. confirm the icon is no longer in running animation
6. confirm the waiting/completed cue plays once if the environment allows hearing it
7. inspect diagnostics to verify normalized transcript preview explains the classification

This walkthrough is mandatory. Do not claim the issue is fixed only from unit tests.

- [ ] **Step 3: Update docs**

Only update `CLAUDE.md` with truths that were actually verified in runtime.

- [ ] **Step 4: Write execution report**

Create:

Report must include:
1. objective recap
2. root cause summary
3. normalized transcript strategy
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
- the user-reported real GUI bug is no longer reproducible
- end-state recognition no longer depends on raw noisy terminal contents
- diagnostics can explain why a session is classified as running / waiting / completed
- waiting/completed state leaves running visual semantics
- waiting/completed cue emission follows the corrected transition
- `swift test` passes
- `swift build` passes
- runtime walkthrough completed
- execution report written to the fixed path
