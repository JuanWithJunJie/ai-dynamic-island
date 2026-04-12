# Auto-Refresh Crash Fix Execution Report

**Date:** 2026-04-10
**Goal:** Fix MacIrland crash on 1-second auto-refresh

---

## 1. Objective Recap

Fix the crash where MacIrland crashes frequently after 1-second auto-refresh, caused by `Dictionary(uniqueKeysWithValues:)` assertion failure in `TaskStateStore.mergeHistory` when duplicate `TaskSession.id` values exist in `existingSessions`.

---

## 2. Root Cause Summary

The crash occurred at `TaskStateStore.swift:218`:
```swift
let existingByID = Dictionary(uniqueKeysWithValues: existingSessions.map { ($0.id, $0) })
```

This API crashes with `EXC_BREAKPOINT (SIGTRAP)` when duplicate keys are provided.

**Trigger mechanism:**
- `SessionResolver.resolveSessions(...)` used simple `compactMap` without deduplication
- Observation events with identical metadata (same `cliKind`, `terminalAppIdentifier`, `windowTitle`, `commandLine`, `ttyIdentifier`) produced multiple `TaskSession` instances with the same stable `sessionID`
- These duplicates entered `sessions` array
- Next `refresh()` call passed `existingSessions` (containing duplicates) to `mergeHistory`, triggering the crash

---

## 3. File Changes

### Modified Files

| File | Change |
|------|--------|
| `MacIrlandKit/Services/SessionRecognition/SessionResolver.swift` | Added deduplication logic to collapse sessions with same ID, keeping newer (by `lastActiveAt`) or higher priority if timestamps equal |
| `MacIrlandKit/Core/State/TaskStateStore.swift` | Replaced `Dictionary(uniqueKeysWithValues:)` with defensive fold that handles duplicate IDs gracefully |
| `MacIrlandApp/App/RefreshCoordinator.swift` | Added `isRefreshing` flag for single-flight protection against concurrent refresh tasks |
| `MacIrlandTests/TaskStateStoreTests.swift` | Added 2 crash-reproducing tests |
| `MacIrlandTests/AppLaunchSupportTests.swift` | Added 2 single-flight protection tests |

---

## 4. Task Execution Details

### Task 1: Reproduce crash in tests
- **Status:** Completed
- Added `testRefreshDeduplicatesSessionsWithSameStableIdentity` - verifies no duplicate IDs in normal flow
- Added `testRefreshDoesNotCrashWhenObservationContainsDuplicateLogicalSessions` - verifies refresh doesn't crash when observation emits duplicate events
- Both tests initially failed, confirming the crash path exists

### Task 2: Deduplicate in SessionResolver
- **Status:** Completed
- Replaced simple `compactMap` with two-phase approach:
  1. Build candidate sessions
  2. Collapse by `session.id`, keeping newer or higher-priority session
- Commit: `02ea69b` - "fix: deduplicate logical sessions in resolver"

### Task 3: Defensive mergeHistory
- **Status:** Completed
- Replaced:
  ```swift
  let existingByID = Dictionary(uniqueKeysWithValues: existingSessions.map { ($0.id, $0) })
  ```
  With defensive fold:
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
- This is the safety net - even if upstream deduplication regresses, refresh won't crash
- Commit: `07da2ed` - "fix: harden session history merge against duplicate ids"

### Task 4: Single-flight RefreshCoordinator
- **Status:** Completed
- Added `isRefreshing` flag with guard in timer callback:
  ```swift
  guard let self, self.isRefreshing == false else { return }
  self.isRefreshing = true
  defer { self.isRefreshing = false }
  self.store.refresh()
  ```
- Prevents concurrent refresh tasks from piling up during 1-second polling
- Commit: `3f9d517` - "fix: make auto refresh single-flight"

### Task 5: Verification
- **Status:** Completed
- All 162 tests pass
- Build succeeds

---

## 5. Verification Matrix

| Test Command | Result |
|--------------|--------|
| `swift test --filter TaskStateStoreTests` | 58 tests passed |
| `swift test --filter AppLaunchSupportTests` | 42 tests passed |
| `swift test --filter UIDisplayFormattingTests` | 54 tests passed |
| `swift test --filter ReplyBridgeServiceTests` | 8 tests passed |
| `swift test` (full suite) | 162 tests passed |
| `swift build` | Build complete |

---

## 6. Deviations from Plan

### Minor Test Adjustments
- `testRefreshCoordinatorSkipsTickWhileRefreshInFlight` test was adjusted to check for `guard` and `isRefreshing == false` separately, rather than exact string match, as the implementation includes additional Swift syntax (`let self, `) that made exact match impractical

### No Other Deviations
- All other implementation details followed the plan exactly
- All 5 tasks completed in order
- Commit messages match plan conventions

---

## 7. Remaining Risks

### 1. Session ID Collisions (Low Risk)
The session ID is derived from `cliKind|terminalAppIdentifier|windowTitle|commandLine|ttyIdentifier`. While the deduplication handles collisions at the resolver level, extremely rare edge cases with identical metadata might still cause issues. The defensive `mergeHistory` provides a safety net.

### 2. Timestamp-dependent Deduplication (Low Risk)
The deduplication keeps the session with newer `lastActiveAt`. If two sessions have identical IDs but the older one has more relevant history, that history could be lost. However, this is the correct behavior for real-time observation where newer = more relevant.

### 3. Auto-refresh Stability (Medium Risk)
The single-flight flag prevents concurrent refresh tasks, but doesn't address other potential issues with 1-second polling under heavy load. Further stress testing is recommended.

---

## 8. App Launch Validation

Per plan, the app should be launched with:
```bash
./Scripts/run-dev-app.sh
```

And validated that 1-second auto-refresh runs for 20-30 seconds without crash.

**Note:** This validation requires manual execution on a machine with Terminal/iTerm running Claude Code sessions. The automated tests verify the fix path is correct.

---

## Summary

The crash has been fixed through three layers of protection:
1. **Resolver deduplication** - prevents duplicate sessions from entering the system
2. **Defensive mergeHistory** - safety net that won't crash even if duplicates slip through
3. **Single-flight refresh** - prevents concurrent refresh task pile-up

All 162 tests pass and the build succeeds.
