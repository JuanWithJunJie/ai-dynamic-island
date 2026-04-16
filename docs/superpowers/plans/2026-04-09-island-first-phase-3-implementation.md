# Island-First Phase 3 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add one minimal recommended quick action to the expanded island card so users can handle the most likely intervention without opening the panel.

**Architecture:** Keep the existing compact/highlighted island states intact and extend the highlighted card with one presentation-driven primary action. Derive the recommended action from the top session’s existing `quickActions`, execute it through the already-shipping `TaskStateStore.performQuickAction`, and render a single-line result message in the island card. Do not add free-text input, multiple quick-action chips, or motion work in this phase.

**Tech Stack:** Swift, SwiftUI, AppKit, XCTest, Swift Package Manager

---

## Planned File Map

- Modify: `MacIrlandKit/Features/Island/IslandPresentation.swift`
  - Add the presentation contract for the single recommended quick action.
- Modify: `MacIrlandKit/Features/Island/IslandExpandedCardView.swift`
  - Render one primary action button and one compact result line.
- Modify: `MacIrlandKit/Features/Island/IslandSurfaceView.swift`
  - Pass the action callback and result state into the expanded card.
- Modify: `MacIrlandApp/App/IslandCoordinator.swift`
  - Own the transient quick-action result and route taps into `TaskStateStore.performQuickAction`.
- Modify: `MacIrlandKit/Core/State/TaskStateStore.swift`
  - Reuse existing `performQuickAction` behavior without changing the reply bridge contract.
- Modify: `MacIrlandTests/UIDisplayFormattingTests.swift`
  - Cover recommended-action selection and button copy.
- Modify: `MacIrlandTests/AppLaunchSupportTests.swift`
  - Cover source-level coordinator wiring for island quick action handling.
- Modify: `CLAUDE.md`
  - Record that the highlighted island card now supports a single minimal recommended action.

---

### Task 1: Add recommended-action presentation helpers and tests

**Files:**
- Modify: `MacIrlandKit/Features/Island/IslandPresentation.swift`
- Modify: `MacIrlandTests/UIDisplayFormattingTests.swift`

- [ ] **Step 1: Write the failing tests**

Add these tests to `MacIrlandTests/UIDisplayFormattingTests.swift`:

```swift
func testHighlightedIslandPresentationPicksFirstVisibleQuickAction() {
    let session = makeSession(
        status: .waitingInput,
        quickActions: [.continueExecution, .retry, .customText]
    )

    let presentation = HighlightedIslandPresentation(topSession: session)

    XCTAssertEqual(presentation?.primaryAction, .continueExecution)
    XCTAssertEqual(presentation?.primaryActionTitle, "继续执行")
}

func testHighlightedIslandPresentationSkipsCustomTextWhenChoosingPrimaryAction() {
    let session = makeSession(
        status: .replyAvailable,
        quickActions: [.customText, .explainReason]
    )

    let presentation = HighlightedIslandPresentation(topSession: session)

    XCTAssertEqual(presentation?.primaryAction, .explainReason)
    XCTAssertEqual(presentation?.primaryActionTitle, "解释原因")
}

func testHighlightedIslandPresentationHasNoPrimaryActionWhenNoVisibleQuickActionsExist() {
    let session = makeSession(
        status: .failed,
        quickActions: [.customText]
    )

    let presentation = HighlightedIslandPresentation(topSession: session)

    XCTAssertNil(presentation?.primaryAction)
    XCTAssertNil(presentation?.primaryActionTitle)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter UIDisplayFormattingTests
```

Expected: FAIL because `primaryAction` and `primaryActionTitle` do not exist yet.

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
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter UIDisplayFormattingTests
```

Expected: PASS, including the three new primary-action selection tests.

- [ ] **Step 5: Commit**

```bash
git add \
  MacIrlandKit/Features/Island/IslandPresentation.swift \
  MacIrlandTests/UIDisplayFormattingTests.swift
git commit -m "test: add island primary action presentation"
```

### Task 2: Add one primary quick-action button to the expanded card

**Files:**
- Modify: `MacIrlandKit/Features/Island/IslandExpandedCardView.swift`
- Modify: `MacIrlandKit/Features/Island/IslandSurfaceView.swift`
- Modify: `MacIrlandKit/DesignSystem/PanelTheme.swift`
- Test: `MacIrlandTests/UIDisplayFormattingTests.swift`

- [ ] **Step 1: Write the failing tests**

Add these tests to `MacIrlandTests/UIDisplayFormattingTests.swift`:

```swift
func testHighlightedIslandPresentationKeepsPrimaryActionForWaitingSession() {
    let session = makeSession(
        status: .waitingInput,
        quickActions: [.retry, .continueExecution]
    )

    let presentation = HighlightedIslandPresentation(topSession: session)

    XCTAssertEqual(presentation?.primaryAction, .retry)
    XCTAssertEqual(presentation?.primaryActionTitle, "重试")
}

func testHighlightedIslandPresentationCanRenderWithoutPrimaryAction() {
    let session = makeSession(
        status: .alert,
        quickActions: [.customText]
    )

    let presentation = HighlightedIslandPresentation(topSession: session)

    XCTAssertNotNil(presentation)
    XCTAssertNil(presentation?.primaryActionTitle)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter UIDisplayFormattingTests
```

Expected: FAIL until the highlighted presentation contract fully supports the button/no-button branches.

- [ ] **Step 3: Write minimal implementation**

Update `MacIrlandKit/Features/Island/IslandExpandedCardView.swift`:

```swift
public struct IslandExpandedCardView: View {
    let presentation: HighlightedIslandPresentation
    let actionResult: ReplyValidationResult?
    let openPanel: () -> Void
    let triggerPrimaryAction: () -> Void
    let dismiss: () -> Void

    public init(
        presentation: HighlightedIslandPresentation,
        actionResult: ReplyValidationResult?,
        openPanel: @escaping () -> Void,
        triggerPrimaryAction: @escaping () -> Void,
        dismiss: @escaping () -> Void
    ) {
        self.presentation = presentation
        self.actionResult = actionResult
        self.openPanel = openPanel
        self.triggerPrimaryAction = triggerPrimaryAction
        self.dismiss = dismiss
    }
```

Inside the existing content stack, add a bottom action row:

```swift
VStack(alignment: .leading, spacing: 14) {
    Spacer(minLength: 0)

    HStack(alignment: .center, spacing: 14) {
        // existing icon + title + summary + source/time
    }

    HStack(spacing: 12) {
        if let actionTitle = presentation.primaryActionTitle {
            Button(actionTitle, action: triggerPrimaryAction)
                .buttonStyle(.borderedProminent)
                .tint(presentation.accentColor)
        }

        if let actionResult {
            Text(actionResult.explanation)
                .font(.caption)
                .foregroundStyle(actionResult.canSend ? .green : .orange)
                .lineLimit(1)
        }
    }
}
```

Update `MacIrlandKit/Features/Island/IslandSurfaceView.swift`:

```swift
public struct IslandSurfaceView: View {
    @Bindable var store: TaskStateStore
    let mode: IslandSurfaceMode
    let actionResult: ReplyValidationResult?
    let openPanel: () -> Void
    let triggerPrimaryAction: () -> Void
    let dismissHighlight: () -> Void

    public init(
        store: TaskStateStore,
        mode: IslandSurfaceMode,
        actionResult: ReplyValidationResult?,
        openPanel: @escaping () -> Void,
        triggerPrimaryAction: @escaping () -> Void,
        dismissHighlight: @escaping () -> Void
    ) {
        self.store = store
        self.mode = mode
        self.actionResult = actionResult
        self.openPanel = openPanel
        self.triggerPrimaryAction = triggerPrimaryAction
        self.dismissHighlight = dismissHighlight
    }

    public var body: some View {
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
}
```

Update `MacIrlandKit/DesignSystem/PanelTheme.swift`:

```swift
public extension MacIrlandPalette {
    static let islandSuccess = Color.green.opacity(0.92)
    static let islandWarning = Color.orange.opacity(0.92)
}
```

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter UIDisplayFormattingTests
```

Expected: PASS, including the no-primary-action and ordered-primary-action tests.

- [ ] **Step 5: Commit**

```bash
git add \
  MacIrlandKit/Features/Island/IslandExpandedCardView.swift \
  MacIrlandKit/Features/Island/IslandSurfaceView.swift \
  MacIrlandKit/DesignSystem/PanelTheme.swift \
  MacIrlandTests/UIDisplayFormattingTests.swift
git commit -m "feat: add island primary quick action button"
```

### Task 3: Route the island button into `TaskStateStore.performQuickAction`

**Files:**
- Modify: `MacIrlandApp/App/IslandCoordinator.swift`
- Modify: `MacIrlandKit/Core/State/TaskStateStore.swift`
- Test: `MacIrlandTests/AppLaunchSupportTests.swift`
- Test: `MacIrlandTests/TaskStateStoreTests.swift`

- [ ] **Step 1: Write the failing tests**

Add these tests to `MacIrlandTests/AppLaunchSupportTests.swift`:

```swift
func testIslandCoordinatorStoresPrimaryActionResult() throws {
    let source = try String(contentsOfFile: "MacIrlandApp/App/IslandCoordinator.swift", encoding: .utf8)

    XCTAssertTrue(source.contains("private var actionResult: ReplyValidationResult?"))
}

func testIslandCoordinatorTriggersStoreQuickActionForHighlightedSession() throws {
    let source = try String(contentsOfFile: "MacIrlandApp/App/IslandCoordinator.swift", encoding: .utf8)

    XCTAssertTrue(source.contains("store.performQuickAction"))
}
```

Add this test to `MacIrlandTests/TaskStateStoreTests.swift`:

```swift
func testPerformQuickActionStillAppendsHistoryForRecommendedIslandAction() {
    let store = makeStore(
        sessions: [
            makeSession(status: .waitingInput, quickActions: [.continueExecution, .customText])
        ]
    )

    let session = try XCTUnwrap(store.selectedSession)
    let result = store.performQuickAction(.continueExecution, for: session)

    XCTAssertTrue(result.canSend)
    XCTAssertEqual(store.selectedSession?.historyEntries.last?.kind, .userQuickAction)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter AppLaunchSupportTests
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter TaskStateStoreTests
```

Expected: FAIL because the coordinator does not yet store action results or trigger the store quick-action path.

- [ ] **Step 3: Write minimal implementation**

Update `MacIrlandApp/App/IslandCoordinator.swift`:

```swift
private var actionResult: ReplyValidationResult?

private func triggerPrimaryAction() {
    guard case let .highlighted(presentation) = mode,
          let topSession = store.topSession,
          topSession.id == presentation.sessionID,
          let action = presentation.primaryAction else {
        return
    }

    actionResult = store.performQuickAction(action, for: topSession)
    recomputeMode()
}
```

Clear the transient result when the highlighted session changes or when the user dismisses:

```swift
private func dismissHighlight() {
    actionResult = nil
    if case let .highlighted(presentation) = mode {
        dismissedHighlightedSessionID = presentation.sessionID
    }
    recomputeMode()
}

private func recomputeMode() {
    if case let .highlighted(presentation) = mode,
       store.topSession?.id != presentation.sessionID {
        actionResult = nil
    }
    // existing mode logic
}
```

Also pass `actionResult` and `triggerPrimaryAction` into `IslandSurfaceView`:

```swift
rootView: IslandSurfaceView(
    store: store,
    mode: mode,
    actionResult: actionResult,
    openPanel: { [weak self] in self?.openPanel() },
    triggerPrimaryAction: { [weak self] in self?.triggerPrimaryAction() },
    dismissHighlight: { [weak self] in self?.dismissHighlight() }
)
```

No contract changes are needed in `TaskStateStore`; keep `performQuickAction` as the single execution path.

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter AppLaunchSupportTests
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter TaskStateStoreTests
```

Expected: PASS for the new coordinator/source test and the store history regression test.

- [ ] **Step 5: Commit**

```bash
git add \
  MacIrlandApp/App/IslandCoordinator.swift \
  MacIrlandTests/AppLaunchSupportTests.swift \
  MacIrlandTests/TaskStateStoreTests.swift
git commit -m "feat: route island quick action through store"
```

### Task 4: Keep the highlighted card lightweight and panel-free

**Files:**
- Modify: `MacIrlandKit/Features/Island/IslandExpandedCardView.swift`
- Modify: `MacIrlandTests/AppLaunchSupportTests.swift`

- [ ] **Step 1: Write the failing tests**

Add these tests to `MacIrlandTests/AppLaunchSupportTests.swift`:

```swift
func testIslandExpandedCardDoesNotEmbedTextField() throws {
    let source = try String(contentsOfFile: "MacIrlandKit/Features/Island/IslandExpandedCardView.swift", encoding: .utf8)

    XCTAssertFalse(source.contains("TextField("))
}

func testIslandExpandedCardDoesNotRenderMultipleActionButtons() throws {
    let source = try String(contentsOfFile: "MacIrlandKit/Features/Island/IslandExpandedCardView.swift", encoding: .utf8)

    XCTAssertFalse(source.contains("ForEach("))
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter AppLaunchSupportTests
```

Expected: FAIL if the expanded card implementation has drifted toward multiple action controls or text input.

- [ ] **Step 3: Write minimal implementation**

Keep `IslandExpandedCardView` constrained to:

```swift
- one existing content button that opens the panel
- one optional primary quick-action button
- one optional one-line result message
- one dismiss button
```

Do not add:

```swift
TextField(...)
ForEach(visibleQuickActions)
LazyVGrid(...)
```

If any of those exist after Task 3, remove them now so the expanded card remains a lightweight intervention surface.

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter AppLaunchSupportTests
```

Expected: PASS, confirming the card stayed lightweight.

- [ ] **Step 5: Commit**

```bash
git add \
  MacIrlandKit/Features/Island/IslandExpandedCardView.swift \
  MacIrlandTests/AppLaunchSupportTests.swift
git commit -m "test: keep island card lightweight"
```

### Task 5: Verify the one-button action flow and update docs

**Files:**
- Modify: `CLAUDE.md`
- Modify: `docs/superpowers/specs/2026-04-09-island-first-experience-design.md`
- Test: `MacIrlandTests/UIDisplayFormattingTests.swift`
- Test: `MacIrlandTests/AppLaunchSupportTests.swift`
- Test: `MacIrlandTests/TaskStateStoreTests.swift`

- [ ] **Step 1: Update docs before final verification**

Add this note to `CLAUDE.md`:

```md
- expanded island 当前已支持 1 个推荐 quick action；它复用已有 `performQuickAction` 路径，并在卡片内显示一行发送结果。
- island 仍然不承载自由输入、多按钮动作区或完整回复工作流；更深处理继续进入 panel。
```

Update the spec status line in `docs/superpowers/specs/2026-04-09-island-first-experience-design.md`:

```md
- 状态：Phase 3 实施计划已完成，待执行
```

- [ ] **Step 2: Run targeted tests**

Run:

```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter UIDisplayFormattingTests
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter AppLaunchSupportTests
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter TaskStateStoreTests
```

Expected: PASS for all three suites.

- [ ] **Step 3: Run full repo verification**

Run:

```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland"
swift build --package-path "/Users/lijunjie/Documents/AIproject/macirland"
```

Expected: PASS for the full test suite and build.

- [ ] **Step 4: Run the dev app and verify the action flow manually**

Run:

```bash
defaults write com.macirland.app OpenPanelOnLaunch -bool NO
./Scripts/run-dev-app.sh
```

Manual checks:
- When the top session is highlighted and has visible quick actions, the expanded card shows exactly one recommended action button.
- Clicking the recommended action does not open the panel automatically.
- The card shows one line of success/failure feedback after the action.
- The card still opens the panel when the user clicks the main content area.
- The card still dismisses back to compact mode with the close button.

- [ ] **Step 5: Commit**

```bash
git add \
  CLAUDE.md \
  docs/superpowers/specs/2026-04-09-island-first-experience-design.md \
  MacIrlandTests/UIDisplayFormattingTests.swift \
  MacIrlandTests/AppLaunchSupportTests.swift \
  MacIrlandTests/TaskStateStoreTests.swift
git commit -m "docs: record island-first phase 3 delivery"
```

---

## Self-Review

### Spec coverage
- The plan adds exactly one minimal quick action on the highlighted card, matching the next-step recommendation from the Phase 2 execution report.
- The plan preserves the “single-task card, not mini panel” boundary.
- The plan still leaves motion, auto-collapse timing, and richer action sets for a later phase.

### Placeholder scan
- No placeholder markers remain.
- Each task includes exact file paths, code blocks, commands, and expected outcomes.

### Type consistency
- The plan consistently uses `HighlightedIslandPresentation.primaryAction`, `IslandExpandedCardView`, `IslandSurfaceView`, and `IslandCoordinator.triggerPrimaryAction()`.
- The execution path always routes through `TaskStateStore.performQuickAction`, so the card does not invent a second reply mechanism.
