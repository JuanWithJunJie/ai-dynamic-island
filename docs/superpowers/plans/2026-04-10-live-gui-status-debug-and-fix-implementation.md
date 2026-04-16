# 2026-04-10 Live GUI Status Debug And Fix Implementation Plan

## Goal

Fix the still-reproducible real-world bug where a Claude Code session has already handed control back to the user, but MacIrland continues to show `运行中`, and no waiting/completed cue plays.

This round is explicitly **not** about adding more heuristic keywords in the dark. It is about making the live GUI classification path inspectable, capturing the actual failing session evidence from the running app, and then fixing the classification/cue chain against that evidence.

## Problem Statement

The previous round fixed a real code-path bug (`RawCLIEvent` carrying title-only snippet instead of transcript), and tests now prove that normalized transcript content can drive the correct end-state classification.

However, the user still observes the original production bug in the running app:

- Claude Code task finishes and waits for the next instruction
- MacIrland still shows `运行中`
- no cue plays

This means the remaining issue is likely one of:

1. the live GUI path is still not feeding the transcript we think it is,
2. the transcript being fed differs from the test transcript shape,
3. normalization strips or misses the real handoff signal,
4. session state transition is being overwritten later in the pipeline,
5. cue gating is correct in tests but not on the final live transition path.

## Non-Goals

- Do not add new UI surfaces unrelated to debugging/fixing this bug
- Do not rework tray, onboarding, island size, or hover behavior
- Do not lower refresh frequency
- Do not rewrite the entire observation architecture

## Target Outcome

After this round:

- a real Claude Code session that has finished and is waiting for the user no longer shows `运行中`
- the session visibly transitions to `等待输入` / `可回复` / `已完成`
- the corresponding cue plays once on the actual live transition
- diagnostics can explain exactly why the session was classified that way

## Architecture Direction

### 1. Make live classification evidence visible

The app must expose the actual inputs used in the running GUI path for the currently focused Claude session:

- raw transcript preview
- normalized transcript preview
- matched status signals / reason
- final judged status
- whether the cue service saw a transition

This should live in the existing diagnostics layer, not in a new debug panel.

### 2. Use a single source of truth for Claude status judgement

Ensure the final status used by:

- island
- panel
- tray
- cue emission

comes from the same judged session status, with no later fallback silently reclassifying it as `running`.

### 3. Capture the real failing transcript shape

Once the diagnostics expose live evidence, reproduce the user-reported state and capture the exact real transcript shape that still fails.

Then:

- add a regression test from that exact shape
- fix normalization / signal extraction / precedence accordingly

### 4. Verify cue emission on the real transition

Do not stop at classification.

Verify that when the live status leaves `running`:

- the icon leaves the running animation
- the cue service emits the expected sound event exactly once

If needed, expose lightweight diagnostics for the last emitted cue and timestamp.

## Task Breakdown

### Task 1: Expose live classification evidence in diagnostics

Update diagnostics so the current Claude-focused session can reveal:

- raw preview
- normalized preview
- decision reason / matched signal
- final judged status
- last cue emitted (if available)

This must be visible enough to debug, but remain in the low-priority diagnostics layer.

### Task 2: Reproduce the real failing case and capture evidence

Use the live app to reproduce:

- Claude finishes
- MacIrland still shows `运行中`

Then record the exact evidence from diagnostics:

- raw preview
- normalized preview
- decision reason
- final status

### Task 3: Add failing regression coverage from the real evidence

Turn the real captured transcript shape into tests that currently fail before the fix:

- live-like transcript still misclassified as `running`
- expected end-state should be `waitingInput`, `replyAvailable`, or `completed`

### Task 4: Fix classification and transition propagation

Based on the real captured evidence, adjust the minimal necessary pieces:

- transcript normalization
- signal extraction / precedence
- status propagation path
- cue transition trigger path

The fix should be evidence-driven, not speculative.

### Task 5: Real GUI validation and report

Re-run the live GUI scenario and confirm:

- running -> waiting/reply/completed transition now occurs
- icon changes accordingly
- sound cue emits once
- diagnostics explain the result

Then write the execution report.

## Files Likely Involved

- `MacIrlandKit/Services/Observation/ObservationService.swift`
- `MacIrlandKit/Adapters/BuiltIn/BuiltInCLIAdapter.swift`
- `MacIrlandKit/Core/State/TaskStateStore.swift`
- `MacIrlandKit/Services/Feedback/FeedbackService.swift`
- `MacIrlandKit/Features/Diagnostics/DiagnosticsSectionView.swift`
- `MacIrlandKit/Core/Models/TaskModels.swift`
- `MacIrlandTests/TaskStateStoreTests.swift`
- `MacIrlandTests/UIDisplayFormattingTests.swift`
- `CLAUDE.md`

## Verification

Required verification:

- `swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter TaskStateStoreTests`
- `swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter UIDisplayFormattingTests`
- `swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland"`
- `swift build --package-path "/Users/lijunjie/Documents/AIproject/macirland"`

Required live walkthrough:

1. Start app
2. Start a real Claude Code task
3. Let it finish and hand control back
4. Confirm the session no longer remains `运行中`
5. Confirm cue plays once
6. Confirm diagnostics explain the classification

## Deliverable

Write the execution report to:


The report must include:

1. objective recap
2. live failing evidence captured
3. root cause summary
4. file changes
5. task execution details
6. verification matrix
7. runtime walkthrough evidence
8. deviations from plan
9. remaining risks
10. release recommendation
