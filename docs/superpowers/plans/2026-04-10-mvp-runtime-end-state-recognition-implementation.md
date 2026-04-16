# MVP Runtime End-State Recognition Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修复 `mac-island-mvp.mp4` 里真实出现的两个问题：Claude Code 已结束并把控制权交还给用户后，MacIrland 仍显示 `运行中`，并且没有触发等待/完成提示音与图标切换。

**Architecture:** 当前声音和图标链路本身基本是通的，但它们都依赖 `TaskStatus` 跃迁。问题根因不是音频播放器本身，而是 `ObservationService` / `BuiltInCLIAdapter` 对真实 Claude transcript 的结束态识别不够强，尤其缺少中文问答式收尾和短句式 handoff/completion 模式。下一轮应先补真实 transcript 识别，再让等待态和完成态在视觉上比当前 `.idle` 更明确。

**Tech Stack:** Swift, SwiftUI, AppKit, Observation, XCTest, AVFoundation

---

## Inputs

### Must review first
- `example/mac-island-mvp.mp4`
- current code in:
  - `MacIrlandKit/Services/Observation/ObservationService.swift`
  - `MacIrlandKit/Adapters/BuiltIn/BuiltInCLIAdapter.swift`
  - `MacIrlandKit/Services/Feedback/FeedbackService.swift`
  - `MacIrlandKit/Features/Icon/AnimatedStatusIcon.swift`
  - `MacIrlandKit/Features/Island/IslandStatusStripView.swift`

### Real-world bugs to fix
- Claude Code 已经输出结果并回到等待用户输入，但 island 仍显示 `运行中`
- 状态没有正确离开 `running` 时，不会触发 `.waitingForReply` / `.completed` cue
- post-run 状态即便被映射到 `.idle`，视觉切换也不够明显，用户体感上像“还在跑”

---

## File Structure

### Modify
- `MacIrlandKit/Services/Observation/ObservationService.swift`
- `MacIrlandKit/Adapters/BuiltIn/BuiltInCLIAdapter.swift`
- `MacIrlandKit/Core/Models/TaskModels.swift`
- `MacIrlandKit/Features/Icon/AnimatedStatusIcon.swift`
- `MacIrlandKit/Features/Island/IslandStatusStripView.swift`
- `MacIrlandKit/DesignSystem/DisplayFormatting.swift`
- `MacIrlandTests/TaskStateStoreTests.swift`
- `MacIrlandTests/UIDisplayFormattingTests.swift`
- `MacIrlandTests/AppLaunchSupportTests.swift`
- `CLAUDE.md`

### Create

---

## Task 1: Encode the real end-state patterns shown in mac-island-mvp.mp4

**Files:**
- Modify: `MacIrlandKit/Services/Observation/ObservationService.swift`
- Modify: `MacIrlandKit/Adapters/BuiltIn/BuiltInCLIAdapter.swift`
- Modify: `MacIrlandTests/TaskStateStoreTests.swift`

- [ ] **Step 1: Extract the real transcript patterns from the MVP recording**

Treat `example/mac-island-mvp.mp4` as the source of truth for this round.

Capture the concrete post-run transcript shapes that currently fail, including:
- short answer completions followed by a user-facing offer/help question
- Chinese handoff phrasing like “有什么可以帮你…”, “如果你需要…”, “还可以继续…”
- “work is done, now waiting on the user” cases that do not contain existing English trigger words

Do not guess abstractly; encode patterns that are actually represented in the recording and adjacent real Claude usage.

- [ ] **Step 2: Extend `ClaudeStatusJudge` without making it sloppy**

Required behavior:
- true ongoing work remains `.running`
- assistant has clearly stopped working and is inviting the next user instruction -> prefer `.waitingInput` or `.replyAvailable`
- true done-for-now summaries -> `.completed`

Add Chinese and short-answer end-of-turn signals, but keep anti-signals and thresholds strong enough to avoid turning every conversational line into a completion.

- [ ] **Step 3: Keep adapter and observation logic aligned**

`BuiltInCLIAdapter.status(for:)` must be updated so that adapter-only paths do not drift from `ClaudeStatusJudge`.

If the current code structure makes drift likely, refactor the shared logic minimally so the same semantics are reused rather than duplicated loosely.

- [ ] **Step 4: Add regression tests using realistic failing snippets**

Required coverage:
- Chinese post-run help prompt becomes `waitingInput` or `replyAvailable`
- short “done, now over to you” English/Chinese patterns no longer stay `.running`
- ordinary ongoing explanation still stays `.running`
- adapter and observation agree on the same snippets

- [ ] **Step 5: Run focused verification**

Run:
```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter TaskStateStoreTests
```

---

## Task 2: Make post-run visual state unmistakably non-running

**Files:**
- Modify: `MacIrlandKit/Core/Models/TaskModels.swift`
- Modify: `MacIrlandKit/Features/Icon/AnimatedStatusIcon.swift`
- Modify: `MacIrlandKit/Features/Island/IslandStatusStripView.swift`
- Modify: `MacIrlandKit/DesignSystem/DisplayFormatting.swift`
- Modify: `MacIrlandTests/UIDisplayFormattingTests.swift`
- Modify: `MacIrlandTests/AppLaunchSupportTests.swift`

- [ ] **Step 1: Split waiting-like visual semantics from generic idle**

Current behavior collapses `waitingInput / replyAvailable` into `.idle`, which makes post-run handoff feel too similar to passive idle.

Required behavior:
- `running` -> active green running animation
- `waitingInput / replyAvailable` -> visually distinct “your turn / ready” state
- `completed` -> stable completed state
- truly idle / no-session -> separate passive idle state

Do not keep using the same visual treatment for both “no session” and “Claude is waiting on you”.

- [ ] **Step 2: Ensure compact island uses the refined state consistently**

`IslandStatusStripView` must render icon state from the same preferred session semantics as its text.

Verify there is no remaining path where text says “等待回复” or equivalent while the icon still looks like `running`.

- [ ] **Step 3: Add focused display tests**

Required coverage:
- waitingInput/replyAvailable no longer map to the same icon semantics as no-session idle
- compact island status text and icon state remain aligned
- completed stays visually distinct from waiting

- [ ] **Step 4: Run focused verification**

Run:
```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter UIDisplayFormattingTests
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter AppLaunchSupportTests
```

---

## Task 3: Re-verify sound cues against the corrected status transitions

**Files:**
- Modify: `MacIrlandKit/Services/Feedback/FeedbackService.swift`
- Modify: `MacIrlandTests/TaskStateStoreTests.swift`

- [ ] **Step 1: Verify transition-based cues now fire on the newly recognized post-run states**

Do not change cue semantics unless the investigation proves they are wrong.

The likely expectation is:
- running -> waitingInput/replyAvailable => `.waitingForReply`
- running -> completed => `.completed`

But verify against the corrected real transcript recognition from Task 1.

- [ ] **Step 2: Add/adjust regression tests for the real failing path**

Required coverage:
- the specific previously failing post-run snippet now emits a waiting cue exactly once
- completion-style snippets emit completion cue exactly once
- same post-run state across multiple refreshes does not replay

- [ ] **Step 3: Run focused verification**

Run:
```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter TaskStateStoreTests
```

---

## Task 4: Perform runtime walkthrough against the MVP symptom

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Run full automated verification**

Run:
```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland"
swift build --package-path "/Users/lijunjie/Documents/AIproject/macirland"
```

- [ ] **Step 2: Perform real runtime walkthrough**

Required scenarios:
1. start a real Claude Code task -> compact island shows running
2. let Claude produce a response that hands control back to the user -> compact island leaves running immediately
3. verify the waiting cue plays once on that transition
4. complete a task that should be treated as completed -> completion visual + completion cue happen once
5. confirm post-run icon no longer looks like running animation

This walkthrough is required. Do not claim success based only on unit tests.

- [ ] **Step 3: Update docs**

Update `CLAUDE.md` only with runtime-verified truths about:
- post-run status recognition
- waiting/completed visual semantics
- waiting/completed sound semantics

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
9. publish recommendation

---

## Definition of Done

DoD:
- the real post-run pattern shown in `mac-island-mvp.mp4` no longer stays `running`
- waiting/reply handoff is distinguishable from passive idle
- waiting cue and completion cue fire exactly once on true transition
- post-run icon no longer looks like running animation
- `swift test` passes
- `swift build` passes
- runtime walkthrough completed
- `CLAUDE.md` updated
- execution report written to the fixed path
