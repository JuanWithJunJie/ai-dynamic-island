# Live Claude Status And Hover Consistency Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix two real runtime bugs: Claude Code sessions should leave `运行中` when work is done and waiting for the user, and hover-expand session counts/listing must stay consistent with the top island count.

**Architecture:** Keep the current Claude-first island/panel architecture, but tighten two data paths. First, harden live Claude end-state recognition and ensure waiting transitions can actually trigger cue playback. Second, introduce a single hover-expand session source so the top count, primary detail, and lower list all describe the same set of Claude sessions.

**Tech Stack:** Swift, SwiftUI, XCTest, Observation, AppKit

---

### Task 1: Add regression coverage for live completion/waiting and hover session consistency

**Files:**
- Modify: `MacIrlandTests/TaskStateStoreTests.swift`
- Modify: `MacIrlandTests/AppLaunchSupportTests.swift`

- [ ] **Step 1: Add a failing end-state recognition regression test**

Add a transcript-based test for a realistic Chinese completion/handoff shape that currently falls back to `.running`, for example a prompt-return transcript that says work is done but lacks the older exact phrases.

- [ ] **Step 2: Add a failing hover session consistency test**

Add a store-level test that proves hover-expand should count/show all relevant Claude sessions consistently even when one is terminal or selected as the primary detail session.

- [ ] **Step 3: Add a failing cue-path expectation for waiting sound**

Add a narrow test that confirms the app-wide refresh path no longer drops `.waitingForReply` from playback eligibility.

### Task 2: Harden live Claude end-state recognition

**Files:**
- Modify: `MacIrlandKit/Services/Observation/ObservationService.swift`
- Modify: `MacIrlandKit/Adapters/BuiltIn/BuiltInCLIAdapter.swift` (only if needed)

- [ ] **Step 1: Introduce prompt-return-aware end-state heuristics**

Teach the judge to recognize transcripts that have clearly returned control to the user even when the text uses softer/shorter wording than the older phrase list.

- [ ] **Step 2: Keep status judgement single-sourced**

If the observation path already computed the correct status, make sure later adapter/session-building logic cannot silently drift back to `.running`.

- [ ] **Step 3: Re-run the new status tests**

Run only the new/focused status tests until they pass.

### Task 3: Make waiting transitions audible in the real app

**Files:**
- Modify: `MacIrlandApp/App/RefreshCoordinator.swift`
- Modify: `MacIrlandTests/AppLaunchSupportTests.swift` or a more direct coordinator-facing test file

- [ ] **Step 1: Allow waiting/reply transitions through the refresh cue filter**

Keep execution sounds muted during active running if desired, but do not suppress the user-facing handoff cue when the session enters `waitingInput` / `replyAvailable`.

- [ ] **Step 2: Verify transition-based behavior stays single-fire**

Do not allow the 1s refresh loop to replay the same cue repeatedly after the first transition.

### Task 4: Unify hover-expand session semantics

**Files:**
- Modify: `MacIrlandKit/Core/State/TaskStateStore.swift`
- Modify: `MacIrlandKit/Features/Island/IslandStatusStripView.swift`
- Modify: `MacIrlandKit/Features/Island/IslandHoverExpandView.swift`
- Modify: `MacIrlandApp/App/IslandCoordinator.swift`

- [ ] **Step 1: Add a single hover-expand session source in the store**

Define one Claude-first collection for hover-expand that the UI can use consistently.

- [ ] **Step 2: Split primary hover detail vs secondary hover rows**

The hover detail card should show the primary Claude session; the lower list should show the remaining Claude sessions and label them clearly as `其他会话`.

- [ ] **Step 3: Align compact count with hover semantics**

The count shown in the compact/hover status strip must describe the same session universe as the hover expand experience.

### Task 5: Verification and handoff

**Files:**
- Modify: `CLAUDE.md` (only if current operational notes changed)

- [ ] **Step 1: Run focused tests**

Run:

```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter TaskStateStoreTests
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter AppLaunchSupportTests
```

- [ ] **Step 2: Run full verification**

Run:

```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland"
swift build --package-path "/Users/lijunjie/Documents/AIproject/macirland"
```

- [ ] **Step 3: Record what changed**

Summarize:
- why sessions were still showing `运行中`
- why waiting cue was suppressed
- how hover count/list semantics are now aligned

