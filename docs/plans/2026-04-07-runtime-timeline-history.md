# MacIrland Runtime Timeline History Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Upgrade session detail timeline from a lightweight `recentEvents + recentMessages` merge into a full in-memory runtime history that records phase transitions and user reply actions for each session during the current app run.

**Architecture:** Keep terminal observation and adapter recognition unchanged, but move timeline ownership into `TaskStateStore`. On each refresh, resolve the latest `TaskSession` snapshots, merge them with prior in-memory history by stable session ID, append new history entries only when a meaningful phase transition or user action occurs, and expose the merged history back on `TaskSession` for the detail view. This preserves current MVP boundaries: no persistence across app restarts, no reply bridge rewrite, no diagnostics mixed into the main timeline.

**Tech Stack:** Swift, SwiftUI, Observation, XCTest

---

## Implementation notes

- Work only in the main repo, not `.worktrees/` copies discovered during file search.
- Keep scope tight: runtime-only history, phase-first timeline, no cross-restart storage, no full step/turn model yet.
- Follow TDD. For each behavior change, write the failing test first, run it, then implement the smallest code needed.
- Prefer extending existing models and store merge logic over introducing a new service unless the store becomes unmanageable.
- Commit in small slices after each task.

## History model shape

Add a dedicated runtime-history model instead of overloading `SessionEvent`:

```swift
public enum SessionHistoryKind: String, Codable, Sendable {
    case phaseDiscovered
    case phaseRunning
    case phaseWaitingInput
    case phaseReplyAvailable
    case phaseAlert
    case phaseCompleted
    case phaseFailed
    case phaseContextLost
    case userQuickAction
    case userCustomReply
    case userReplyRejected
}

public struct SessionHistoryEntry: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let kind: SessionHistoryKind
    public let title: String
    public let detail: String
    public let relatedStatus: TaskStatus?
}
```

Design intent:
- `kind` drives UI icon/tint/label mapping.
- `title` and `detail` are captured when the event is created so the UI can stay simple.
- `relatedStatus` lets the UI reuse existing color rules where helpful.

## Merge policy

When `TaskStateStore.refresh()` resolves a fresh set of sessions:

1. Match new sessions to old sessions by `session.id`.
2. For a brand-new session, seed history with one phase entry representing its current status.
3. For an existing session:
   - compare old `status` to new `status`
   - append a new phase history entry only if the status changed
   - do **not** append duplicate phase entries when the same status repeats across refreshes
4. Preserve prior history entries when rebuilding the session array.
5. When a user triggers a quick action or custom send attempt, append a user-action entry to that session immediately.
6. If the send/validation is rejected, record `userReplyRejected` instead of a normal reply entry.

This keeps the history stable, phase-first, and free from duplicate spam.

## UI policy

- `SessionDetailView` should render `session.historyEntries` instead of `session.timelineEntries`.
- Timeline rows should visually emphasize phase changes; user actions can use a quieter style but remain visible.
- Diagnostics stay in `DiagnosticsSectionView`; do not move reader diagnostics into the main timeline.
- Message snippets remain available elsewhere if needed, but they are no longer responsible for representing “complete history”.

---

### Task 1: Add failing model tests for runtime history support

**Files:**
- Modify: `MacIrlandTests/TaskStateStoreTests.swift`
- Modify: `MacIrlandKit/Core/Models/TaskModels.swift`

**Step 1: Write the failing tests**

Add focused tests in `MacIrlandTests/TaskStateStoreTests.swift` for these behaviors:

```swift
func testRefreshAppendsHistoryWhenSessionStatusChanges() {
    let source = MutableObservationService(initialEvents: [runningClaudeEvent])
    let store = TaskStateStore(observationService: source)

    XCTAssertEqual(store.sessions.first?.historyEntries.map(\.kind), [.phaseRunning])

    source.updateEvents([waitingClaudeEvent])
    store.refresh()

    XCTAssertEqual(store.sessions.first?.historyEntries.map(\.kind), [.phaseRunning, .phaseWaitingInput])
}

func testRefreshDoesNotAppendDuplicateHistoryWhenStatusRepeats() {
    let source = MutableObservationService(initialEvents: [runningClaudeEvent])
    let store = TaskStateStore(observationService: source)

    source.updateEvents([runningClaudeEventWithNewSnippet])
    store.refresh()

    XCTAssertEqual(store.sessions.first?.historyEntries.map(\.kind), [.phaseRunning])
}
```

Also add a test that a newly discovered session gets exactly one seed history entry.

**Step 2: Run test to verify it fails**

Run:
```bash
swift test --filter TaskStateStoreTests
```

Expected: FAIL because `TaskSession` has no `historyEntries` and the store does not preserve runtime history.

**Step 3: Write minimal model scaffolding**

In `MacIrlandKit/Core/Models/TaskModels.swift`, add:
- `SessionHistoryKind`
- `SessionHistoryEntry`
- `historyEntries: [SessionHistoryEntry]` on `TaskSession`
- init parameter wiring for `historyEntries`

For now, do not implement merging logic yet; just make the types compile.

**Step 4: Run test to verify compile progresses**

Run:
```bash
swift test --filter TaskStateStoreTests
```

Expected: FAIL moves from compile/type issues to behavior issues around empty history.

**Step 5: Commit**

```bash
git add MacIrlandKit/Core/Models/TaskModels.swift MacIrlandTests/TaskStateStoreTests.swift
git commit -m "Add runtime session history model scaffolding"
```

---

### Task 2: Seed history entries when adapters build sessions

**Files:**
- Modify: `MacIrlandKit/Adapters/BuiltIn/BuiltInCLIAdapter.swift`
- Modify: `MacIrlandKit/Core/Models/TaskModels.swift`
- Test: `MacIrlandTests/TaskStateStoreTests.swift`

**Step 1: Write the failing test**

Add a test that store initialization seeds one history entry matching the initial status:

```swift
func testInitSeedsRuntimeHistoryFromInitialStatus() {
    let store = TaskStateStore(
        observationService: StubObservationService(events: [waitingClaudeEvent], diagnostics: .empty)
    )

    XCTAssertEqual(store.sessions.first?.historyEntries.count, 1)
    XCTAssertEqual(store.sessions.first?.historyEntries.first?.kind, .phaseWaitingInput)
}
```

**Step 2: Run test to verify it fails**

Run:
```bash
swift test --filter TaskStateStoreTests/testInitSeedsRuntimeHistoryFromInitialStatus
```

Expected: FAIL because adapter-built sessions still have no seeded history.

**Step 3: Write minimal implementation**

In `MacIrlandKit/Adapters/BuiltIn/BuiltInCLIAdapter.swift`:
- add a helper mapping `TaskStatus -> SessionHistoryKind`
- create one initial `SessionHistoryEntry` when building each `TaskSession`
- pass `[initialHistoryEntry]` into `TaskSession`

Use current event snippet for `detail`, and a short phase label for `title`, for example:

```swift
SessionHistoryEntry(
    kind: .phaseWaitingInput,
    title: "等待输入",
    detail: event.snippet,
    relatedStatus: status
)
```

**Step 4: Run test to verify it passes**

Run:
```bash
swift test --filter TaskStateStoreTests/testInitSeedsRuntimeHistoryFromInitialStatus
```

Expected: PASS.

**Step 5: Run the broader test file**

Run:
```bash
swift test --filter TaskStateStoreTests
```

Expected: Some new merge-behavior tests still FAIL; seed-history test PASS.

**Step 6: Commit**

```bash
git add MacIrlandKit/Adapters/BuiltIn/BuiltInCLIAdapter.swift MacIrlandKit/Core/Models/TaskModels.swift MacIrlandTests/TaskStateStoreTests.swift
git commit -m "Seed initial runtime history for task sessions"
```

---

### Task 3: Merge runtime history across refreshes without duplicates

**Files:**
- Modify: `MacIrlandKit/Core/State/TaskStateStore.swift`
- Modify: `MacIrlandKit/Core/Models/TaskModels.swift`
- Test: `MacIrlandTests/TaskStateStoreTests.swift`

**Step 1: Write the failing tests**

Add tests for:
- appending a new phase entry when status changes
- preserving old history on refresh
- not appending a duplicate phase entry when status repeats
- seeding a new session with one entry when it appears for the first time during refresh

Example:

```swift
func testRefreshPreservesOldHistoryAndAppendsNewPhase() {
    let source = MutableObservationService(initialEvents: [runningClaudeEvent])
    let store = TaskStateStore(observationService: source)

    source.updateEvents([completedClaudeEvent])
    store.refresh()

    XCTAssertEqual(
        store.sessions.first?.historyEntries.map(\.kind),
        [.phaseRunning, .phaseCompleted]
    )
}
```

**Step 2: Run test to verify it fails**

Run:
```bash
swift test --filter TaskStateStoreTests
```

Expected: FAIL because `refresh()` currently replaces sessions wholesale and discards runtime state.

**Step 3: Write minimal implementation**

In `MacIrlandKit/Core/State/TaskStateStore.swift`:
- after resolving `refreshedSessions`, merge them with existing `sessions`
- create a private helper such as:

```swift
private func mergedSessionsWithRuntimeHistory(_ refreshed: [TaskSession]) -> [TaskSession]
```

Implementation rules:
- build a dictionary of previous sessions by `id`
- if no previous session exists, keep the seeded history from adapter output
- if previous exists:
  - start from `previous.historyEntries`
  - if `previous.status != refreshed.status`, append one new phase entry for `refreshed.status`
  - otherwise keep history unchanged
- return a copied `TaskSession` with merged history

If copying `TaskSession` is awkward, add a narrow helper initializer or `withHistoryEntries(_:)` method in `TaskModels.swift`.

**Step 4: Run test to verify it passes**

Run:
```bash
swift test --filter TaskStateStoreTests
```

Expected: PASS for history merge tests and existing selection-preservation tests.

**Step 5: Commit**

```bash
git add MacIrlandKit/Core/State/TaskStateStore.swift MacIrlandKit/Core/Models/TaskModels.swift MacIrlandTests/TaskStateStoreTests.swift
git commit -m "Preserve runtime session history across refreshes"
```

---

### Task 4: Record quick actions and rejected replies in runtime history

**Files:**
- Modify: `MacIrlandKit/Core/State/TaskStateStore.swift`
- Modify: `MacIrlandKit/Core/Models/TaskModels.swift`
- Modify: `MacIrlandKit/Services/ReplyBridge/ReplyBridgeService.swift`
- Test: `MacIrlandTests/TaskStateStoreTests.swift`

**Step 1: Write the failing tests**

Add tests for both entry points:

```swift
func testPerformQuickActionAppendsRejectedHistoryWhenReplyCannotSend() {
    let store = TaskStateStore(observationService: StubObservationService(events: [waitingClaudeEvent], diagnostics: .empty))
    let session = try XCTUnwrap(store.sessions.first)

    _ = store.performQuickAction(.continueExecution, for: session)

    XCTAssertEqual(store.sessions.first?.historyEntries.last?.kind, .userReplyRejected)
}

func testSendDraftReplyAppendsCustomReplyHistoryWhenValidationPasses() {
    let store = TaskStateStore(
        observationService: StubObservationService(events: [replyAvailableClaudeEvent], diagnostics: .empty),
        replyBridge: AlwaysSendingReplyBridge()
    )
    store.draftReply = "请继续"
    let session = try XCTUnwrap(store.sessions.first)

    _ = store.sendDraftReply(for: session)

    XCTAssertEqual(store.sessions.first?.historyEntries.last?.kind, .userCustomReply)
}
```

Add a tiny test double bridge in the test file if needed:

```swift
private struct AlwaysSendingReplyBridge: ReplyBridging {
    func validateReply(for session: TaskSession, message: String) -> ReplyValidationResult {
        ReplyValidationResult(canSend: true, explanation: "ok")
    }

    func sendReply(to session: TaskSession, message: String) -> ReplyValidationResult {
        ReplyValidationResult(canSend: true, explanation: "sent")
    }
}
```

**Step 2: Run test to verify it fails**

Run:
```bash
swift test --filter TaskStateStoreTests
```

Expected: FAIL because reply actions currently do not mutate session history at all.

**Step 3: Write minimal implementation**

In `TaskStateStore.swift`:
- update `performQuickAction(_:for:)` to:
  - validate the action
  - append `.userQuickAction` if accepted
  - append `.userReplyRejected` if rejected
- update `sendDraftReply(for:)` to:
  - call `replyBridge.sendReply`
  - append `.userCustomReply` when send succeeds
  - append `.userReplyRejected` when it fails
- perform history updates by replacing the matching session inside `sessions`
- do not clear old phase history

Keep the user-action detail strings simple and explicit, e.g.:
- `title: "快速操作 · 继续执行"`
- `detail: "请继续执行。"`
- rejected detail should include the validation explanation

**Step 4: Run test to verify it passes**

Run:
```bash
swift test --filter TaskStateStoreTests
```

Expected: PASS for reply-history tests.

**Step 5: Commit**

```bash
git add MacIrlandKit/Core/State/TaskStateStore.swift MacIrlandKit/Core/Models/TaskModels.swift MacIrlandKit/Services/ReplyBridge/ReplyBridgeService.swift MacIrlandTests/TaskStateStoreTests.swift
git commit -m "Record reply actions in runtime session history"
```

---

### Task 5: Move display formatting from synthetic timeline to runtime history

**Files:**
- Modify: `MacIrlandKit/DesignSystem/DisplayFormatting.swift`
- Modify: `MacIrlandKit/Core/Models/TaskModels.swift`
- Test: `MacIrlandTests/UIDisplayFormattingTests.swift`

**Step 1: Write the failing tests**

Add formatting tests that assert runtime history entries map to expected UI rows:

```swift
func testHistoryEntryFormatsWaitingPhaseRow() {
    let entry = SessionHistoryEntry(
        kind: .phaseWaitingInput,
        title: "等待输入",
        detail: "Need user input",
        relatedStatus: .waitingInput
    )

    let row = entry.timelineRowDisplay

    XCTAssertEqual(row.systemImage, "hand.raised.fill")
    XCTAssertEqual(row.tint, .waitingInput)
}
```

If there is no display helper yet, write tests against the new helper you plan to add.

**Step 2: Run test to verify it fails**

Run:
```bash
swift test --filter UIDisplayFormattingTests
```

Expected: FAIL because history-display mapping does not exist.

**Step 3: Write minimal implementation**

In `MacIrlandKit/DesignSystem/DisplayFormatting.swift`:
- keep `terminalDisplayName`, `relativeLastActiveText`, and `primaryGuidanceText`
- replace or deprecate `timelineEntries` synthesized from `recentEvents + recentMessages`
- add display mapping for `SessionHistoryEntry`, for example:

```swift
public extension SessionHistoryEntry {
    var systemImage: String { ... }
    var tint: TaskStatus { ... }
    var timeText: String { ... }
}

public extension TaskSession {
    var timelineEntries: [SessionHistoryEntry] {
        historyEntries.sorted { $0.timestamp > $1.timestamp }
    }
}
```

Do not delete `recentEvents` / `recentMessages` yet; just stop relying on them for the main timeline.

**Step 4: Run test to verify it passes**

Run:
```bash
swift test --filter UIDisplayFormattingTests
```

Expected: PASS.

**Step 5: Commit**

```bash
git add MacIrlandKit/DesignSystem/DisplayFormatting.swift MacIrlandKit/Core/Models/TaskModels.swift MacIrlandTests/UIDisplayFormattingTests.swift
git commit -m "Map runtime session history into timeline display"
```

---

### Task 6: Update session detail UI to render full runtime history

**Files:**
- Modify: `MacIrlandKit/Features/Panel/SessionDetailView.swift`
- Modify: `MacIrlandKit/DesignSystem/DisplayFormatting.swift`
- Test: `MacIrlandTests/UIDisplayFormattingTests.swift`

**Step 1: Write the failing UI-oriented assertion**

If there are existing display tests that cover timeline ordering, extend them to assert:
- newest history item comes first
- user action rows remain present beside phase rows
- waiting/failed rows use higher-attention tint values

If view-level tests are too heavy, keep this at formatting-level assertions.

**Step 2: Run test to verify it fails**

Run:
```bash
swift test --filter UIDisplayFormattingTests
```

Expected: FAIL because the current UI still assumes `SessionTimelineEntry` built from events/messages.

**Step 3: Write minimal implementation**

In `MacIrlandKit/Features/Panel/SessionDetailView.swift`:
- update the timeline section subtitle from “按时间倒序查看事件和最近消息。” to something phase-history oriented, for example:
  - `按时间倒序查看本次运行期内的关键阶段和你的介入动作。`
- change `TimelineRow` to accept `SessionHistoryEntry`
- use `entry.systemImage`, `entry.tint`, `entry.title`, `entry.detail`, `entry.timeText`
- keep row structure largely unchanged to limit scope

**Step 4: Run tests**

Run:
```bash
swift test --filter UIDisplayFormattingTests
swift test --filter TaskStateStoreTests
```

Expected: PASS.

**Step 5: Commit**

```bash
git add MacIrlandKit/Features/Panel/SessionDetailView.swift MacIrlandKit/DesignSystem/DisplayFormatting.swift MacIrlandTests/UIDisplayFormattingTests.swift MacIrlandTests/TaskStateStoreTests.swift
git commit -m "Render full runtime history in session detail timeline"
```

---

### Task 7: Run full verification and update project notes

**Files:**
- Modify: `CLAUDE.md`
- Optionally modify: `docs/plans/2026-04-07-runtime-timeline-history.md`

**Step 1: Run full verification**

Run:
```bash
swift test --filter TaskStateStoreTests
swift test --filter UIDisplayFormattingTests
swift test
swift build
```

Expected: all PASS.

**Step 2: Update project notes**

Append a concise update to `CLAUDE.md` covering:
- runtime timeline is now maintained in-memory for the current app run
- phase transitions and user reply attempts are preserved in session detail
- duplicate same-status refreshes no longer spam timeline entries
- persistence across relaunch is still intentionally out of scope

**Step 3: Re-run targeted verification if the notes touched package-visible files**

Run:
```bash
swift test --filter TaskStateStoreTests
swift test --filter UIDisplayFormattingTests
```

Expected: PASS.

**Step 4: Commit**

```bash
git add CLAUDE.md docs/plans/2026-04-07-runtime-timeline-history.md MacIrlandKit MacIrlandTests
git commit -m "Add runtime timeline history for session detail"
```

---

## Files likely to change

- `MacIrlandKit/Core/Models/TaskModels.swift`
- `MacIrlandKit/Core/State/TaskStateStore.swift`
- `MacIrlandKit/Adapters/BuiltIn/BuiltInCLIAdapter.swift`
- `MacIrlandKit/DesignSystem/DisplayFormatting.swift`
- `MacIrlandKit/Features/Panel/SessionDetailView.swift`
- `MacIrlandKit/Services/ReplyBridge/ReplyBridgeService.swift` (only if small API/supporting comments or testability tweaks are needed)
- `MacIrlandTests/TaskStateStoreTests.swift`
- `MacIrlandTests/UIDisplayFormattingTests.swift`
- `CLAUDE.md`

## Files explicitly out of scope

- `MacIrlandKit/Services/Observation/ObservationService.swift` — keep observation snapshot generation unchanged
- `MacIrlandKit/Features/Diagnostics/DiagnosticsSectionView.swift` — diagnostics remain separate from the main timeline
- Any persistence/local database layer — runtime history is intentionally in-memory only
- Real reply bridge implementation — still mock for this slice

## Verification checklist

- New sessions seed exactly one phase history entry
- Refresh appends one new history entry only when status changes
- Repeated same-status refreshes do not duplicate phase entries
- Quick actions and custom replies append action history entries
- Rejected replies append rejected history entries
- Detail view renders runtime history in reverse chronological order
- Existing selection reconciliation still works
- `swift test` and `swift build` pass
