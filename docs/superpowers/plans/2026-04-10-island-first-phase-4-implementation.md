# Island-First Phase 4 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add lightweight expand/collapse motion and a small auto-collapse policy so the island feels intentional instead of switching modes abruptly.

**Architecture:** Keep the existing compact/highlighted island states and one-button action flow intact. Introduce a small policy layer that decides which highlighted states auto-collapse and after how long, then let `IslandCoordinator` own timer scheduling and cancellation while `IslandSurfaceView` and `IslandExpandedCardView` own only the visual transition and polish. Do not add hover-specific behavior, gesture choreography, or new interaction surfaces in this phase.

**Tech Stack:** Swift, SwiftUI, AppKit, XCTest, Swift Package Manager

---

## Planned File Map

- Modify: `MacIrlandKit/Features/Island/IslandPresentation.swift`
  - Add an island policy contract for auto-collapse timing per highlighted session status.
- Modify: `MacIrlandKit/Features/Island/IslandExpandedCardView.swift`
  - Add lightweight transition polish without changing the card’s information density.
- Modify: `MacIrlandKit/Features/Island/IslandSurfaceView.swift`
  - Animate compact/highlighted mode changes in one place.
- Modify: `MacIrlandApp/App/IslandCoordinator.swift`
  - Own auto-collapse scheduling, cancellation, and reset behavior.
- Modify: `MacIrlandTests/UIDisplayFormattingTests.swift`
  - Cover auto-collapse policy mapping.
- Modify: `MacIrlandTests/AppLaunchSupportTests.swift`
  - Cover source-level timer scheduling and cancel/reset wiring.
- Modify: `CLAUDE.md`
  - Record the new motion and collapse behavior.
  - Final execution report written after implementation is complete.

---

### Task 1: Add highlighted auto-collapse policy helpers and tests

**Files:**
- Modify: `MacIrlandKit/Features/Island/IslandPresentation.swift`
- Modify: `MacIrlandTests/UIDisplayFormattingTests.swift`

- [ ] **Step 1: Write the failing tests**

Add these tests to `MacIrlandTests/UIDisplayFormattingTests.swift`:

```swift
func testHighlightedIslandPresentationAutoCollapseDelayIsNilForWaitingInput() {
    let session = makeSession(status: .waitingInput)

    let presentation = try XCTUnwrap(HighlightedIslandPresentation(topSession: session))

    XCTAssertNil(presentation.autoCollapseDelay)
}

func testHighlightedIslandPresentationAutoCollapseDelayIsNilForFailedSession() {
    let session = makeSession(status: .failed)

    let presentation = try XCTUnwrap(HighlightedIslandPresentation(topSession: session))

    XCTAssertNil(presentation.autoCollapseDelay)
}

func testHighlightedIslandPresentationAutoCollapseDelayUsesEightSecondsForAlert() {
    let session = makeSession(status: .alert)

    let presentation = try XCTUnwrap(HighlightedIslandPresentation(topSession: session))

    XCTAssertEqual(presentation.autoCollapseDelay, 8)
}

func testHighlightedIslandPresentationAutoCollapseDelayUsesTwelveSecondsForReplyAvailable() {
    let session = makeSession(status: .replyAvailable)

    let presentation = try XCTUnwrap(HighlightedIslandPresentation(topSession: session))

    XCTAssertEqual(presentation.autoCollapseDelay, 12)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter UIDisplayFormattingTests
```

Expected: FAIL because `autoCollapseDelay` does not exist yet.

- [ ] **Step 3: Write minimal implementation**

Update `MacIrlandKit/Features/Island/IslandPresentation.swift`:

```swift
public struct HighlightedIslandPresentation: Equatable {
    public let sessionID: TaskSession.ID
    public let status: TaskStatus
    public let titleText: String
    public let summaryText: String
    public let sourceText: String
    public let timeText: String
    public let accessibilityLabel: String
    public let accentColor: Color
    public let primaryAction: ReplyActionType?
    public let primaryActionTitle: String?
    public let autoCollapseDelay: TimeInterval?

    public init?(topSession: TaskSession?) {
        guard let topSession, topSession.status.needsAttention else {
            return nil
        }

        let visibleQuickActions = topSession.quickActions.filter { $0 != .customText }

        sessionID = topSession.id
        status = topSession.status
        titleText = topSession.title
        summaryText = topSession.compactSessionSubtitle
        sourceText = topSession.sourceCLI.displayName
        timeText = topSession.relativeLastActiveText
        accessibilityLabel = "MacIrland，\(titleText)，\(summaryText)，来自 \(sourceText)"
        accentColor = IslandAccent.color(for: topSession.status)
        primaryAction = visibleQuickActions.first
        primaryActionTitle = visibleQuickActions.first?.title

        switch topSession.status {
        case .alert:
            autoCollapseDelay = 8
        case .replyAvailable:
            autoCollapseDelay = 12
        case .waitingInput, .failed, .contextLost:
            autoCollapseDelay = nil
        default:
            autoCollapseDelay = nil
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter UIDisplayFormattingTests
```

Expected: PASS, including the four new auto-collapse policy tests.

- [ ] **Step 5: Commit**

```bash
git add \
  MacIrlandKit/Features/Island/IslandPresentation.swift \
  MacIrlandTests/UIDisplayFormattingTests.swift
git commit -m "test: add island auto collapse policy"
```

### Task 2: Add lightweight surface animation in the SwiftUI island layer

**Files:**
- Modify: `MacIrlandKit/Features/Island/IslandSurfaceView.swift`
- Modify: `MacIrlandKit/Features/Island/IslandExpandedCardView.swift`
- Modify: `MacIrlandTests/AppLaunchSupportTests.swift`

- [ ] **Step 1: Write the failing tests**

Add these tests to `MacIrlandTests/AppLaunchSupportTests.swift`:

```swift
func testIslandSurfaceViewAnimatesModeChanges() throws {
    let source = try String(contentsOfFile: "MacIrlandKit/Features/Island/IslandSurfaceView.swift", encoding: .utf8)

    XCTAssertTrue(source.contains(".animation("))
    XCTAssertTrue(source.contains("value: mode"))
}

func testIslandExpandedCardUsesTransitionForHighlightedAppearance() throws {
    let source = try String(contentsOfFile: "MacIrlandKit/Features/Island/IslandExpandedCardView.swift", encoding: .utf8)

    XCTAssertTrue(source.contains(".transition("))
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter AppLaunchSupportTests
```

Expected: FAIL because the current island views do not declare animation or transition behavior yet.

- [ ] **Step 3: Write minimal implementation**

Update `MacIrlandKit/Features/Island/IslandSurfaceView.swift`:

```swift
public var body: some View {
    Group {
        switch mode {
        case .compact:
            IslandStatusStripView(store: store, action: openPanel)
        case .highlighted(let presentation):
            IslandExpandedCardView(
                presentation: presentation,
                actionResult: actionResult,
                openPanel: openPanel,
                triggerPrimaryAction: triggerPrimaryAction,
                dismiss: dismissHighlight
            )
        }
    }
    .animation(.spring(response: 0.34, dampingFraction: 0.86), value: mode)
}
```

Update `MacIrlandKit/Features/Island/IslandExpandedCardView.swift` by adding a lightweight transition to the root container:

```swift
.transition(
    .asymmetric(
        insertion: .opacity.combined(with: .scale(scale: 0.98, anchor: .top)),
        removal: .opacity.combined(with: .scale(scale: 0.99, anchor: .top))
    )
)
```

Do not add keyframe animation, matched geometry, hover tracking, or gesture-driven scrubbing in this phase.

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter AppLaunchSupportTests
```

Expected: PASS, including the new animation/transition source tests.

- [ ] **Step 5: Commit**

```bash
git add \
  MacIrlandKit/Features/Island/IslandSurfaceView.swift \
  MacIrlandKit/Features/Island/IslandExpandedCardView.swift \
  MacIrlandTests/AppLaunchSupportTests.swift
git commit -m "feat: add island surface motion"
```

### Task 3: Add coordinator-owned auto-collapse scheduling and cancellation

**Files:**
- Modify: `MacIrlandApp/App/IslandCoordinator.swift`
- Modify: `MacIrlandTests/AppLaunchSupportTests.swift`

- [ ] **Step 1: Write the failing tests**

Add these tests to `MacIrlandTests/AppLaunchSupportTests.swift`:

```swift
func testIslandCoordinatorStoresAutoCollapseWorkItem() throws {
    let source = try String(contentsOfFile: "MacIrlandApp/App/IslandCoordinator.swift", encoding: .utf8)

    XCTAssertTrue(source.contains("private var autoCollapseWorkItem"))
}

func testIslandCoordinatorSchedulesAutoCollapseFromPresentationDelay() throws {
    let source = try String(contentsOfFile: "MacIrlandApp/App/IslandCoordinator.swift", encoding: .utf8)

    XCTAssertTrue(source.contains("presentation.autoCollapseDelay"))
    XCTAssertTrue(source.contains("DispatchWorkItem"))
    XCTAssertTrue(source.contains("DispatchQueue.main.asyncAfter"))
}

func testIslandCoordinatorCancelsAutoCollapseOnDismissAndOpenPanel() throws {
    let source = try String(contentsOfFile: "MacIrlandApp/App/IslandCoordinator.swift", encoding: .utf8)

    XCTAssertTrue(source.contains("autoCollapseWorkItem?.cancel()"))
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter AppLaunchSupportTests
```

Expected: FAIL because the coordinator does not schedule timed collapse yet.

- [ ] **Step 3: Write minimal implementation**

Update `MacIrlandApp/App/IslandCoordinator.swift`:

```swift
private var autoCollapseWorkItem: DispatchWorkItem?

private func cancelAutoCollapse() {
    autoCollapseWorkItem?.cancel()
    autoCollapseWorkItem = nil
}

private func scheduleAutoCollapseIfNeeded(for presentation: HighlightedIslandPresentation) {
    cancelAutoCollapse()

    guard let delay = presentation.autoCollapseDelay else {
        return
    }

    let workItem = DispatchWorkItem { [weak self] in
        guard let self else { return }
        self.dismissedHighlightedSessionID = presentation.sessionID
        self.actionResult = nil
        self.recomputeMode()
    }

    autoCollapseWorkItem = workItem
    DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
}
```

Inside `recomputeMode()`:

```swift
if let topSession = store.topSession,
   topSession.id != dismissedHighlightedSessionID,
   let highlighted = HighlightedIslandPresentation(topSession: topSession) {
    mode = .highlighted(highlighted)
    window.setContentSize(CGSize(width: 860, height: 152))
    scheduleAutoCollapseIfNeeded(for: highlighted)
} else {
    mode = .compact
    window.setContentSize(CGSize(width: 520, height: 44))
    cancelAutoCollapse()
}
```

Also cancel pending collapse inside:

```swift
private func dismissHighlight() {
    cancelAutoCollapse()
    actionResult = nil
    // existing dismiss logic
}

private func openPanel() {
    cancelAutoCollapse()
    action()
    dismissedHighlightedSessionID = nil
    recomputeMode()
}

private func triggerPrimaryAction() {
    cancelAutoCollapse()
    // existing quick action logic
}
```

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter AppLaunchSupportTests
```

Expected: PASS, including the auto-collapse scheduling/cancelation tests.

- [ ] **Step 5: Commit**

```bash
git add \
  MacIrlandApp/App/IslandCoordinator.swift \
  MacIrlandTests/AppLaunchSupportTests.swift
git commit -m "feat: add island auto collapse scheduling"
```

### Task 4: Keep blocking states persistent and non-blocking states transient

**Files:**
- Modify: `MacIrlandKit/Features/Island/IslandPresentation.swift`
- Modify: `MacIrlandTests/UIDisplayFormattingTests.swift`

- [ ] **Step 1: Write the failing tests**

Add these tests to `MacIrlandTests/UIDisplayFormattingTests.swift`:

```swift
func testHighlightedIslandPresentationKeepsContextLostPersistent() {
    let session = makeSession(status: .contextLost)

    let presentation = try XCTUnwrap(HighlightedIslandPresentation(topSession: session))

    XCTAssertNil(presentation.autoCollapseDelay)
}

func testHighlightedIslandPresentationKeepsWaitingInputPersistentEvenWithPrimaryAction() {
    let session = makeSession(
        status: .waitingInput,
        quickActions: [.continueExecution, .customText]
    )

    let presentation = try XCTUnwrap(HighlightedIslandPresentation(topSession: session))

    XCTAssertEqual(presentation.primaryActionTitle, "继续执行")
    XCTAssertNil(presentation.autoCollapseDelay)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter UIDisplayFormattingTests
```

Expected: FAIL until the persistence policy is fully encoded.

- [ ] **Step 3: Write minimal implementation**

Keep the status policy exactly as follows inside `HighlightedIslandPresentation`:

```swift
switch topSession.status {
case .alert:
    autoCollapseDelay = 8
case .replyAvailable:
    autoCollapseDelay = 12
case .waitingInput, .failed, .contextLost:
    autoCollapseDelay = nil
default:
    autoCollapseDelay = nil
}
```

Do not add auto-collapse for:

```swift
.waitingInput
.failed
.contextLost
```

This preserves the “needs deeper user attention” states until the user acts, dismisses, or the top session changes.

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter UIDisplayFormattingTests
```

Expected: PASS for the new persistence-policy tests.

- [ ] **Step 5: Commit**

```bash
git add \
  MacIrlandKit/Features/Island/IslandPresentation.swift \
  MacIrlandTests/UIDisplayFormattingTests.swift
git commit -m "test: lock island persistence policy"
```

### Task 5: Verify motion/collapse behavior and write the execution report

**Files:**
- Modify: `CLAUDE.md`
- Modify: `docs/superpowers/specs/2026-04-09-island-first-experience-design.md`
- Test: `MacIrlandTests/UIDisplayFormattingTests.swift`
- Test: `MacIrlandTests/AppLaunchSupportTests.swift`

- [ ] **Step 1: Update docs before final verification**

Add this note to `CLAUDE.md`:

```md
- island 现已具备轻量展开/收回动效，并按状态执行不同的自动收回策略：`alert` 与 `replyAvailable` 为短暂停留，`waitingInput` / `failed` / `contextLost` 保持常驻直到用户处理或关闭。
```

Update the spec status line in `docs/superpowers/specs/2026-04-09-island-first-experience-design.md`:

```md
- 状态：Phase 4 实施计划已完成，待执行
```

- [ ] **Step 2: Run targeted tests**

Run:

```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter UIDisplayFormattingTests
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter AppLaunchSupportTests
```

Expected: PASS for both suites.

- [ ] **Step 3: Run full repo verification**

Run:

```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland"
swift build --package-path "/Users/lijunjie/Documents/AIproject/macirland"
```

Expected: PASS for the full test suite and build.

- [ ] **Step 4: Run the dev app and verify the strategy manually**

Run:

```bash
defaults write com.macirland.app OpenPanelOnLaunch -bool NO
./Scripts/run-dev-app.sh
```

Manual checks:
- Compact → highlighted switches with visible but restrained motion.
- Highlighted → compact dismiss also uses the same lightweight motion style.
- `alert` highlighted cards auto-collapse after about 8 seconds.
- `replyAvailable` highlighted cards auto-collapse after about 12 seconds.
- `waitingInput`, `failed`, and `contextLost` highlighted cards do not auto-collapse on their own.
- Clicking the main card or the primary action cancels any pending timed collapse.

- [ ] **Step 5: Write the execution report**


```md
# Island-First Phase 4 执行报告

- 日期
- 状态
- 执行分支

## 目标回顾
## 文件变更清单
## Task 执行明细
## 验证矩阵
## 与 plan 的偏差说明
## 当前架构
## 下一步建议
```

The report must include:
- the exact files changed
- the exact test/build commands run
- which auto-collapse rules shipped
- whether the execution deviated from the plan

- [ ] **Step 6: Commit**

```bash
git add \
  CLAUDE.md \
  docs/superpowers/specs/2026-04-09-island-first-experience-design.md \
  MacIrlandTests/UIDisplayFormattingTests.swift \
  MacIrlandTests/AppLaunchSupportTests.swift
git commit -m "docs: record island-first phase 4 delivery"
```

---

## Self-Review

### Spec coverage
- The plan implements the next recommended slice from the Phase 3 execution report: motion and collapse strategy.
- The plan keeps the island card lightweight and does not expand the interaction surface beyond the existing one-button action.
- The plan distinguishes transient vs persistent highlighted states, which matches the current product direction.

### Placeholder scan
- No placeholder markers remain.
- Each task includes exact file paths, code blocks, commands, and expected outcomes.

### Type consistency
- The plan consistently uses `HighlightedIslandPresentation.autoCollapseDelay`, `IslandCoordinator.autoCollapseWorkItem`, and `IslandSurfaceView` as the animation boundary.
- Timer policy stays in `IslandCoordinator`, while visual motion stays in SwiftUI views.
