# Hook-First Session Identity And Jump Fix Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Align MacIrland's Claude multi-session detection and session jump behavior with the hook-first design in `example/claude-island-multi-session-detection.md`, so multi-session identity is stable and click-to-jump reliably targets the intended Claude Code session.

**Architecture:** Promote Claude hook events to the authoritative session source, use `hook session_id` as the primary business identity for Claude sessions, and downgrade AppleScript observation to enrichment/fallback. Unify display, jump, and reply targeting so every layer uses the same session identity chain instead of mixing `tty`, `windowTitle`, `fullWindowName`, `TERM_SESSION_ID`, and `sessionName` ad hoc.

**Tech Stack:** Swift, AppKit, AppleScript, Unix socket hook transport, XCTest

---

## Reference

Primary design reference:
- `/Users/lijunjie/Documents/AIproject/macirland/example/claude-island-multi-session-detection.md`

Key mismatches already identified in the current codebase:
- Hook installation writes only the Python script, but does not register hooks into `~/.claude/settings.json`.
- Hook events do not create sessions when no AppleScript-observed session exists yet.
- Claude session identity is still primarily derived from `tty`, not `hook session_id`.
- Jump and reply layers do not share one canonical target identity.

---

## File Map

**Likely modify**
- `/Users/lijunjie/Documents/AIproject/macirland/MacIrlandKit/Services/Hooks/HookInstaller.swift`
  Purpose: install hook script and merge MacIrland hook registration into `~/.claude/settings.json`.
- `/Users/lijunjie/Documents/AIproject/macirland/MacIrlandKit/Services/Hooks/HookSocketServer.swift`
  Purpose: keep socket transport aligned with documented runtime expectations and diagnostics.
- `/Users/lijunjie/Documents/AIproject/macirland/MacIrlandKit/Services/Hooks/HookEvent.swift`
  Purpose: maintain hook event schema and any session identity fields needed by the store.
- `/Users/lijunjie/Documents/AIproject/macirland/MacIrlandKit/Core/Models/TaskModels.swift`
  Purpose: encode canonical session identity fields shared by UI, jump, and reply layers.
- `/Users/lijunjie/Documents/AIproject/macirland/MacIrlandKit/Core/State/TaskStateStore.swift`
  Purpose: create and merge sessions from hook events, preserve canonical identity, and expose stable selection/jump behavior.
- `/Users/lijunjie/Documents/AIproject/macirland/MacIrlandKit/Adapters/BuiltIn/BuiltInCLIAdapter.swift`
  Purpose: change Claude session stable ID generation to prefer `hookSessionID`.
- `/Users/lijunjie/Documents/AIproject/macirland/MacIrlandKit/Services/TerminalJump/TerminalJumpService.swift`
  Purpose: resolve jump targets using the unified target identity instead of mixed heuristics.
- `/Users/lijunjie/Documents/AIproject/macirland/MacIrlandKit/Services/ReplyBridge/ReplyBridgeService.swift`
  Purpose: use the same canonical target identity as jump logic and stop relying on mismatched title fields.
- `/Users/lijunjie/Documents/AIproject/macirland/MacIrlandApp/App/IslandCoordinator.swift`
  Purpose: ensure session row click handling preserves the intended `TaskSession.ID` end-to-end.
- `/Users/lijunjie/Documents/AIproject/macirland/example/claude-island-multi-session-detection.md`
  Purpose: update only if implementation intentionally keeps a different socket path or other divergence.

**Likely add/modify tests**
- `/Users/lijunjie/Documents/AIproject/macirland/MacIrlandTests/TaskStateStoreTests.swift`
- `/Users/lijunjie/Documents/AIproject/macirland/MacIrlandTests/AppLaunchSupportTests.swift`
- Any focused test file added for hook installer, jump service, or reply bridge if existing tests become too crowded

---

## Task 1: Make Hook Installation Match The Reference Design

**Files:**
- Modify: `/Users/lijunjie/Documents/AIproject/macirland/MacIrlandKit/Services/Hooks/HookInstaller.swift`
- Test: `/Users/lijunjie/Documents/AIproject/macirland/MacIrlandTests/TaskStateStoreTests.swift` or a new focused hook installer test file

- [ ] **Step 1: Write failing tests for hook registration**

Test cases to add:
- installing the hook writes the script to `~/.claude/hooks/macirland.py`
- installing the hook also merges MacIrland entries into `~/.claude/settings.json`
- existing unrelated user hook configuration is preserved

- [ ] **Step 2: Run the focused tests to verify they fail**

Run:
```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter Hook
```

Expected:
- at least one new hook installer test fails because `settings.json` is not updated today

- [ ] **Step 3: Implement incremental `settings.json` hook registration**

Implementation requirements:
- create `~/.claude/settings.json` if absent
- merge only the MacIrland hook registrations required by the reference design
- do not clobber existing user keys
- make the socket path and invoked script path consistent with runtime code

- [ ] **Step 4: Re-run focused hook installer tests**

Run:
```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter Hook
```

Expected:
- all hook installer tests pass

---

## Task 2: Make Hook Events Create Sessions Instead Of Being Dropped

**Files:**
- Modify: `/Users/lijunjie/Documents/AIproject/macirland/MacIrlandKit/Core/State/TaskStateStore.swift`
- Modify: `/Users/lijunjie/Documents/AIproject/macirland/MacIrlandKit/Core/Models/TaskModels.swift`
- Test: `/Users/lijunjie/Documents/AIproject/macirland/MacIrlandTests/TaskStateStoreTests.swift`

- [ ] **Step 1: Write failing tests for hook-first session creation**

Test cases to add:
- `processHookEvent(_:)` creates a new session when no AppleScript-observed session exists
- created session stores `hookSessionID`, `tty`, `cwd`-derived title/project signal, and hook-derived status
- later AppleScript refresh enriches the same logical session instead of creating a duplicate

- [ ] **Step 2: Run focused store tests to verify failure**

Run:
```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter TaskStateStoreTests
```

Expected:
- new hook-first tests fail because unmatched hook events currently return early

- [ ] **Step 3: Implement hook-first session creation**

Implementation requirements:
- if `hookSessionID` matches an existing session, update that session
- else if `tty` matches exactly one existing session missing `hookSessionID`, hydrate that session with `hookSessionID`
- else create a new Claude session immediately from the hook event
- do not require AppleScript observation as a prerequisite

- [ ] **Step 4: Re-run focused store tests**

Run:
```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter TaskStateStoreTests
```

Expected:
- hook-first creation tests pass

---

## Task 3: Make `hookSessionID` The Primary Claude Session Identity

**Files:**
- Modify: `/Users/lijunjie/Documents/AIproject/macirland/MacIrlandKit/Adapters/BuiltIn/BuiltInCLIAdapter.swift`
- Modify: `/Users/lijunjie/Documents/AIproject/macirland/MacIrlandKit/Core/Models/TaskModels.swift`
- Modify: `/Users/lijunjie/Documents/AIproject/macirland/MacIrlandKit/Core/State/TaskStateStore.swift`
- Test: `/Users/lijunjie/Documents/AIproject/macirland/MacIrlandTests/TaskStateStoreTests.swift`

- [ ] **Step 1: Write failing identity tests**

Test cases to add:
- same `hookSessionID` with drifting `windowTitle` still resolves to one session
- same `tty` but different `hookSessionID` yields distinct sessions
- hook-updated session keeps the same `TaskSession.ID` across observation refreshes

- [ ] **Step 2: Run the focused identity tests to verify they fail**

Run:
```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter TaskStateStoreTests
```

Expected:
- at least one identity test fails because the current stable ID logic still prefers `tty`

- [ ] **Step 3: Implement canonical Claude identity ordering**

Implementation requirements:
- for Claude Code, stable identity preference must become:
  1. `hookSessionID`
  2. `terminalAppIdentifier + tty`
  3. text fallback
- make merge logic prefer a known `hookSessionID` over observation-only identity

- [ ] **Step 4: Re-run focused identity tests**

Run:
```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter TaskStateStoreTests
```

Expected:
- identity tests pass

---

## Task 4: Unify Jump And Reply Target Identity

**Files:**
- Modify: `/Users/lijunjie/Documents/AIproject/macirland/MacIrlandKit/Services/TerminalJump/TerminalJumpService.swift`
- Modify: `/Users/lijunjie/Documents/AIproject/macirland/MacIrlandKit/Services/ReplyBridge/ReplyBridgeService.swift`
- Modify: `/Users/lijunjie/Documents/AIproject/macirland/MacIrlandKit/Core/Models/TaskModels.swift`
- Test: add or modify focused jump/reply regression tests

- [ ] **Step 1: Write failing tests for target consistency**

Test cases to add:
- jump and reply use the same identity fields for the same session
- a full window name / short window title mismatch does not invalidate a valid target
- multi-session rows with distinct `tty` values jump to the intended session rather than the first Claude tab

- [ ] **Step 2: Run focused jump/reply tests to verify failure**

Run:
```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter Jump
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter Reply
```

Expected:
- new jump/reply consistency tests fail under current mixed identity logic

- [ ] **Step 3: Implement one target identity contract**

Contract requirements:
- `hookSessionID` is the business identity
- `tty` is the terminal-level locator
- `terminalAppIdentifier` scopes the locator
- `windowTitle`, `fullWindowName`, `TERM_SESSION_ID`, and `sessionName` are only fallback/debug aids
- eliminate exact equality assumptions between `windowIdentifier` and `bridgeTarget.terminalContext` when those fields come from different source shapes

- [ ] **Step 4: Re-run focused jump/reply tests**

Run:
```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter Jump
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter Reply
```

Expected:
- jump and reply identity tests pass

---

## Task 5: Make Multi-Session UI Clicks Deterministic

**Files:**
- Modify: `/Users/lijunjie/Documents/AIproject/macirland/MacIrlandApp/App/IslandCoordinator.swift`
- Modify: `/Users/lijunjie/Documents/AIproject/macirland/MacIrlandKit/Core/State/TaskStateStore.swift`
- Modify: `/Users/lijunjie/Documents/AIproject/macirland/MacIrlandKit/Features/Island/IslandHoverExpandView.swift`
- Test: `/Users/lijunjie/Documents/AIproject/macirland/MacIrlandTests/AppLaunchSupportTests.swift` and/or new focused interaction tests

- [ ] **Step 1: Write failing tests for row-to-session mapping**

Test cases to add:
- hover expand secondary rows preserve distinct `TaskSession.ID`s
- clicking a given secondary session row calls jump using that exact session ID
- selected session / preferred session / hover primary session do not collapse multiple sessions into one jump target

- [ ] **Step 2: Run focused UI/controller tests to verify failure**

Run:
```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter AppLaunchSupportTests
```

Expected:
- at least one new session jump mapping test fails

- [ ] **Step 3: Implement deterministic click-to-jump flow**

Implementation requirements:
- row tap must carry the row’s exact `TaskSession.ID`
- coordinator lookup must remain stable against reorderings
- avoid any “first matching Claude session” fallback once a row-specific ID exists

- [ ] **Step 4: Re-run focused UI/controller tests**

Run:
```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter AppLaunchSupportTests
```

Expected:
- UI/controller jump mapping tests pass

---

## Task 6: Add Diagnostics For Session Identity And Jump Resolution

**Files:**
- Modify: `/Users/lijunjie/Documents/AIproject/macirland/MacIrlandKit/Features/Diagnostics/DiagnosticsSectionView.swift`
- Modify: `/Users/lijunjie/Documents/AIproject/macirland/MacIrlandKit/Core/Models/TaskModels.swift`
- Modify: `/Users/lijunjie/Documents/AIproject/macirland/MacIrlandKit/Services/TerminalJump/TerminalJumpService.swift`
- Test: diagnostics-focused tests if coverage exists, otherwise use existing formatting tests

- [ ] **Step 1: Write a failing diagnostics expectation**

Test cases to add:
- diagnostics expose `hookSessionID`
- diagnostics expose jump lookup basis or jump failure reason
- diagnostics make it obvious whether a session came from hook, AppleScript, or both

- [ ] **Step 2: Run focused diagnostics tests to verify failure**

Run:
```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter UIDisplayFormattingTests
```

Expected:
- new diagnostics assertions fail

- [ ] **Step 3: Implement diagnostics surfacing**

Implementation requirements:
- add user-visible but engineering-oriented fields for:
  - `hookSessionID`
  - `tty`
  - target identity used by jump
  - why a jump matched or failed

- [ ] **Step 4: Re-run focused diagnostics tests**

Run:
```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter UIDisplayFormattingTests
```

Expected:
- diagnostics tests pass

---

## Final Verification

- [ ] **Step 1: Run full test suite**

Run:
```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland"
```

Expected:
- all tests pass

- [ ] **Step 2: Run package build**

Run:
```bash
swift build --package-path "/Users/lijunjie/Documents/AIproject/macirland"
```

Expected:
- build complete

- [ ] **Step 3: Launch the app and do a runtime walkthrough**

Run:
```bash
./Scripts/run-dev-app.sh
```

Runtime checks:
- open two or more Claude Code sessions
- verify each appears as a distinct session in the island
- click each session row and confirm the correct terminal session is activated
- verify hook-driven sessions appear even if AppleScript observation lags

- [ ] **Step 4: Write execution report**

Create:

Report must include:
- files changed
- root cause summary
- before/after identity model
- test commands run
- runtime validation results
- residual risks

---

## Claude Code Prompt

Use the following prompt in Claude Code:

```text
Please execute a Hook-first multi-session identity and session jump fix in:

/Users/lijunjie/Documents/AIproject/macirland

You must first read and align implementation to this reference design:
- /Users/lijunjie/Documents/AIproject/macirland/example/claude-island-multi-session-detection.md

You must also read this implementation plan and follow it strictly with TDD:
- /Users/lijunjie/Documents/AIproject/macirland/docs/superpowers/plans/2026-04-12-hook-first-session-identity-and-jump-fix-plan.md

Primary goal:
- make hook the primary discovery/update path
- make `hook session_id` the primary Claude session identity
- stop dropping unmatched hook events
- make multi-session click-to-jump reliable
- unify display, jump, and reply target identity

You must modify the relevant implementation in:
- /Users/lijunjie/Documents/AIproject/macirland/MacIrlandKit/Services/Hooks/HookInstaller.swift
- /Users/lijunjie/Documents/AIproject/macirland/MacIrlandKit/Services/Hooks/HookSocketServer.swift
- /Users/lijunjie/Documents/AIproject/macirland/MacIrlandKit/Services/Hooks/HookEvent.swift
- /Users/lijunjie/Documents/AIproject/macirland/MacIrlandKit/Core/Models/TaskModels.swift
- /Users/lijunjie/Documents/AIproject/macirland/MacIrlandKit/Core/State/TaskStateStore.swift
- /Users/lijunjie/Documents/AIproject/macirland/MacIrlandKit/Adapters/BuiltIn/BuiltInCLIAdapter.swift
- /Users/lijunjie/Documents/AIproject/macirland/MacIrlandKit/Services/TerminalJump/TerminalJumpService.swift
- /Users/lijunjie/Documents/AIproject/macirland/MacIrlandKit/Services/ReplyBridge/ReplyBridgeService.swift
- /Users/lijunjie/Documents/AIproject/macirland/MacIrlandApp/App/IslandCoordinator.swift

Non-negotiable requirements:
1. Hook installation must merge required hook registrations into ~/.claude/settings.json
2. processHookEvent must create sessions when they do not already exist
3. Claude session stable identity must prefer hookSessionID over tty
4. Jump and reply must use one canonical target identity contract
5. Multi-session row click must jump to the exact intended Claude session, not the first matching Claude window
6. Add diagnostics that explain session identity and jump matching

You must use TDD:
- write failing tests first
- run focused tests and confirm failure
- implement minimal code
- rerun focused tests
- rerun full test suite

Do not stop at writing a plan. Complete the implementation, verification, and execution report.

When done, write the execution report to:

The report must include:
- files changed
- root cause summary
- before/after identity model
- test commands run
- runtime validation results
- residual risks
```

