# Auto-Refresh Crash Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修复 MacIrland 在 1 秒自动刷新后经常闪退的问题，优先消除 `TaskStateStore.refresh()` 路径中的崩溃，并为自动刷新链路补上稳定性回归测试。

**Architecture:** 当前崩溃根因已经明确，不是 UI 问题，也不是 Timer 本身崩，而是自动刷新更频繁地触发了重复逻辑 session 的刷新路径。`TaskStateStore.mergeHistory(from:into:)` 使用 `Dictionary(uniqueKeysWithValues:)` 构建 `existingByID`，一旦 `existingSessions` 中出现重复 `TaskSession.id` 就会直接断言崩溃。正确修复应该是：先在 session 解析/聚合阶段消除重复 logical session，再把 `mergeHistory` 做成防御式实现，最后根据 1 秒轮询特征加上 single-flight 刷新保护，避免刷新任务堆积。

**Tech Stack:** Swift, SwiftUI, AppKit, `TaskStateStore`, `SessionResolver`, `RefreshCoordinator`, XCTest

---

## Root Cause Summary

已从 `bug/bug.json` 确认的关键信息：

- `Exception Type: EXC_BREAKPOINT (SIGTRAP)`
- 崩溃线程：`Thread 0`
- 崩溃栈：

```text
Dictionary.init(uniqueKeysWithValues:)
TaskStateStore.mergeHistory(from:into:)  (TaskStateStore.swift:218)
TaskStateStore.refresh()                 (TaskStateStore.swift:127)
closure in RefreshCoordinator.start()    (RefreshCoordinator.swift:19)
```

这表明：

1. `1s` 自动刷新确实在触发崩溃路径
2. 真正的断点来自 `Dictionary(uniqueKeysWithValues:)`
3. 只有在 key 重复时这个 API 才会直接断言
4. 因此 `existingSessions.map { ($0.id, $0) }` 中出现了重复 `TaskSession.id`

当前最可能的触发机制是：
- `SessionResolver.resolveSessions(...)` 对 observation events 直接 `compactMap`
- 没有对同一 logical session 去重
- 某些 Terminal/iTerm snapshot 会生成多个拥有同一稳定 `sessionID` 的 `TaskSession`
- 这些重复项进入 `sessions`
- 下一轮 `refresh()` 时在 `mergeHistory` 里直接崩溃

---

## File Structure

### Modify
- `MacIrlandKit/Services/SessionRecognition/SessionResolver.swift`
- `MacIrlandKit/Core/State/TaskStateStore.swift`
- `MacIrlandApp/App/RefreshCoordinator.swift`
- `MacIrlandTests/TaskStateStoreTests.swift`
- `MacIrlandTests/AppLaunchSupportTests.swift`
- `CLAUDE.md`

### Create

---

### Task 1: Reproduce the duplicate-session crash in tests

**Files:**
- Modify: `MacIrlandTests/TaskStateStoreTests.swift`

- [ ] **Step 1: Write the failing tests**

Add tests that reproduce duplicate logical sessions from observation input.

Required coverage:
- `resolveSessions` can currently return multiple `TaskSession`s with the same stable ID
- `TaskStateStore.refresh()` must not crash when observation emits duplicate logical sessions
- duplicate logical sessions should collapse into one final session

Add tests along these lines:

```swift
func testRefreshDeduplicatesSessionsWithSameStableIdentity() {
    let duplicateEvents = [waitingClaudeEvent, waitingClaudeEvent]
    let source = MutableObservationService(initialEvents: duplicateEvents)
    let store = TaskStateStore(observationService: source)

    XCTAssertEqual(Set(store.sessions.map(\.id)).count, store.sessions.count)
}

func testRefreshDoesNotCrashWhenObservationContainsDuplicateLogicalSessions() {
    let source = MutableObservationService(initialEvents: [runningClaudeEvent])
    let store = TaskStateStore(observationService: source)

    source.updateEvents([waitingClaudeEvent, waitingClaudeEvent])
    store.refresh()

    XCTAssertEqual(store.sessions.count, 1)
    XCTAssertEqual(store.sessions.first?.status, .waitingInput)
}
```

If needed, create two events with:
- same terminal app
- same window title
- same command line
- same tty
- different snippet/timestamp

so they intentionally hash to the same stable `sessionID`.

- [ ] **Step 2: Run the tests to verify they fail**

Run:
```bash
swift test --filter TaskStateStoreTests
```

Expected:
- one or more new tests fail, or refresh path crashes

- [ ] **Step 3: Commit failing test checkpoint if your workflow uses it**

```bash
git add MacIrlandTests/TaskStateStoreTests.swift
git commit -m "test: reproduce duplicate-session refresh crash"
```

---

### Task 2: Deduplicate logical sessions in SessionResolver

**Files:**
- Modify: `MacIrlandKit/Services/SessionRecognition/SessionResolver.swift`
- Modify: `MacIrlandTests/TaskStateStoreTests.swift`

- [ ] **Step 1: Implement minimal deduplication in resolver**

Current resolver is:

```swift
events.compactMap { event in
    let adapter = ...
    return adapter?.buildSession(from: event)
}
```

Replace with a two-step approach:
- build candidate sessions
- collapse duplicates by `session.id`

When duplicate IDs exist, keep the stronger candidate using:
1. newer `lastActiveAt`
2. if tied, higher `priority`
3. if still tied, larger evidence / message payload is acceptable as deterministic tiebreak

Suggested implementation shape:

```swift
let candidates = events.compactMap { event -> TaskSession? in
    let adapter = registry.adapter(for: event.snapshot) ?? registry.adapters.first(where: { $0.cliKind == event.cliKind })
    return adapter?.buildSession(from: event)
}

var dedupedByID: [TaskSession.ID: TaskSession] = [:]
for session in candidates {
    guard let existing = dedupedByID[session.id] else {
        dedupedByID[session.id] = session
        continue
    }

    if session.lastActiveAt > existing.lastActiveAt {
        dedupedByID[session.id] = session
    } else if session.lastActiveAt == existing.lastActiveAt, session.priority > existing.priority {
        dedupedByID[session.id] = session
    }
}

return Array(dedupedByID.values)
```

Keep it small and deterministic. Do not redesign the adapter layer in this task.

- [ ] **Step 2: Re-run the focused tests**

Run:
```bash
swift test --filter TaskStateStoreTests
```

Expected:
- duplicate-session tests now pass or move the remaining failure into `mergeHistory`

- [ ] **Step 3: Commit**

```bash
git add MacIrlandKit/Services/SessionRecognition/SessionResolver.swift MacIrlandTests/TaskStateStoreTests.swift
git commit -m "fix: deduplicate logical sessions in resolver"
```

---

### Task 3: Make mergeHistory defensive against duplicate IDs

**Files:**
- Modify: `MacIrlandKit/Core/State/TaskStateStore.swift`
- Modify: `MacIrlandTests/TaskStateStoreTests.swift`

- [ ] **Step 1: Add a failing defensive test**

Add a test that simulates pre-existing duplicated sessions and verifies `refresh()` no longer traps.

If direct state injection is awkward, expose the behavior via a resolver/observation setup that creates duplicates on initialization and then refreshes again.

At minimum, assert that after refresh:
- no duplicate IDs remain
- history is preserved for the surviving session

- [ ] **Step 2: Run focused tests**

Run:
```bash
swift test --filter TaskStateStoreTests
```

- [ ] **Step 3: Implement defensive mergeHistory**

Do **not** leave this as:

```swift
Dictionary(uniqueKeysWithValues: existingSessions.map { ($0.id, $0) })
```

Replace it with a defensive fold:

```swift
var existingByID: [TaskSession.ID: TaskSession] = [:]
for session in existingSessions {
    if let existing = existingByID[session.id] {
        if session.lastActiveAt > existing.lastActiveAt {
            existingByID[session.id] = session
        }
    } else {
        existingByID[session.id] = session
    }
}
```

Do the same for `refreshedSessions` if needed before mapping history.

This task is the safety net:
- even if upstream dedupe regresses later, `refresh()` must not crash the app

- [ ] **Step 4: Re-run focused tests**

Run:
```bash
swift test --filter TaskStateStoreTests
```

- [ ] **Step 5: Commit**

```bash
git add MacIrlandKit/Core/State/TaskStateStore.swift MacIrlandTests/TaskStateStoreTests.swift
git commit -m "fix: harden session history merge against duplicate ids"
```

---

### Task 4: Prevent auto-refresh pile-up with single-flight scheduling

**Files:**
- Modify: `MacIrlandApp/App/RefreshCoordinator.swift`
- Modify: `MacIrlandTests/AppLaunchSupportTests.swift`

- [ ] **Step 1: Write the failing tests**

Add source-level tests asserting:
- `RefreshCoordinator` contains a single-flight/in-progress guard
- timer callback does not unconditionally enqueue unlimited `Task {}` refreshes

Suggested checks:

```swift
func testRefreshCoordinatorTracksInFlightRefresh() throws {
    let source = try String(contentsOfFile: refreshCoordinatorPath)
    XCTAssertTrue(source.contains("isRefreshing"))
}

func testRefreshCoordinatorSkipsTickWhileRefreshInFlight() throws {
    let source = try String(contentsOfFile: refreshCoordinatorPath)
    XCTAssertTrue(source.contains("guard isRefreshing == false else"))
}
```

- [ ] **Step 2: Run focused tests**

Run:
```bash
swift test --filter AppLaunchSupportTests
```

- [ ] **Step 3: Implement minimal single-flight protection**

Update `RefreshCoordinator`:

```swift
private var isRefreshing = false
```

and in timer callback:

```swift
Task { @MainActor [weak self] in
    guard let self, self.isRefreshing == false else { return }
    self.isRefreshing = true
    defer { self.isRefreshing = false }
    self.store.refresh()
}
```

This is not the primary root-cause fix, but it is valid hardening for 1-second polling.

- [ ] **Step 4: Re-run focused tests**

Run:
```bash
swift test --filter AppLaunchSupportTests
```

- [ ] **Step 5: Commit**

```bash
git add MacIrlandApp/App/RefreshCoordinator.swift MacIrlandTests/AppLaunchSupportTests.swift
git commit -m "fix: make auto refresh single-flight"
```

---

### Task 5: Verify crash fix, update docs, and record execution report

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Run full verification**

Run:
```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland"
swift build --package-path "/Users/lijunjie/Documents/AIproject/macirland"
```

- [ ] **Step 2: Launch the app and validate stability**

Run:
```bash
cd /Users/lijunjie/Documents/AIproject/macirland
./Scripts/run-dev-app.sh
```

Then keep it running long enough to validate that 1-second auto-refresh no longer crashes immediately.

If practical, wait at least 20-30 seconds before declaring success.

- [ ] **Step 3: Update docs**

Update `CLAUDE.md` with:
- crash root cause summary
- dedupe / defensive merge / single-flight hardening
- remaining refresh risks, if any

- [ ] **Step 4: Write execution report**

Write:

Must include:
- objective recap
- root cause summary
- changed files
- test matrix
- any deviations from plan
- remaining risks

- [ ] **Step 5: Commit**

```bash
git commit -m "docs: record auto refresh crash fix"
```

---

## Self-Review

### 1. Root cause coverage
- duplicate logical sessions reproduced: Task 1
- resolver-level dedupe: Task 2
- mergeHistory safety net: Task 3
- 1-second refresh hardening: Task 4
- end-to-end validation: Task 5

### 2. Placeholder scan
- no TBD/TODO placeholders
- each task has concrete files, commands, and minimal implementation shape

### 3. Scope check
- focused on crash and auto-refresh stability only
- does not expand into unrelated UI work

---

Plan complete and saved to `docs/superpowers/plans/2026-04-10-auto-refresh-crash-fix-implementation.md`. Two execution options:

**1. Subagent-Driven (recommended)** - 我按任务逐个派发子代理实现，并在每个任务后 review

**2. Inline Execution** - 我在当前会话里直接按计划开始实现

Which approach?
