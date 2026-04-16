# Island-First Phase 2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the expanded single-task island card so MacIrland can switch from the compact status strip into a high-priority highlighted surface for one session at a time.

**Architecture:** Keep the Phase 1 compact island intact and extend the existing island layer with a presentation-driven two-state surface: compact summary vs expanded single-task card. Add a lightweight highlighted-session presentation model in `MacIrlandKit`, render it via a dedicated expanded-card view, and let `IslandCoordinator` own the surface mode, sizing, dismiss, and panel handoff logic. Do not add quick-action buttons, free-text input, or complex animations in this phase.

**Tech Stack:** Swift, SwiftUI, AppKit, XCTest, Swift Package Manager

---

## Planned File Map

- Modify: `MacIrlandKit/Features/Island/IslandPresentation.swift`
  - Extend the existing island presentation layer with highlighted-card content and state helpers.
- Create: `MacIrlandKit/Features/Island/IslandExpandedCardView.swift`
  - Own the expanded single-task card UI.
- Create: `MacIrlandKit/Features/Island/IslandSurfaceView.swift`
  - Switch between compact strip and expanded card without pushing that branching into AppKit.
- Modify: `MacIrlandApp/App/IslandCoordinator.swift`
  - Own surface mode, dismiss/reset behavior, resize the overlay window, and route taps into the panel.
- Modify: `MacIrlandApp/App/PanelCoordinator.swift`
  - Reuse the existing `showPanel()` flow and keep panel behavior stable.
- Modify: `MacIrlandKit/DesignSystem/PanelTheme.swift`
  - Add any shared island-card palette or border tokens needed by the expanded card.
- Modify: `MacIrlandTests/UIDisplayFormattingTests.swift`
  - Cover highlighted-presentation mapping and card copy.
- Modify: `MacIrlandTests/AppLaunchSupportTests.swift`
  - Cover source-level coordinator wiring for surface mode, resize, and dismiss handling.
- Modify: `CLAUDE.md`
  - Record that MacIrland now has compact + expanded island states, while panel/menu bar/Dock remain fallback or deeper layers.

---

### Task 1: Add highlighted-island presentation helpers and tests

**Files:**
- Modify: `MacIrlandKit/Features/Island/IslandPresentation.swift`
- Modify: `MacIrlandKit/DesignSystem/DisplayFormatting.swift`
- Test: `MacIrlandTests/UIDisplayFormattingTests.swift`

- [ ] **Step 1: Write the failing tests**

Add these tests to `MacIrlandTests/UIDisplayFormattingTests.swift`:

```swift
func testHighlightedIslandPresentationUsesWaitingSessionCopy() {
    let session = makeSession(status: .waitingInput)

    let presentation = HighlightedIslandPresentation(topSession: session)

    XCTAssertEqual(presentation?.titleText, "UI refresh")
    XCTAssertEqual(presentation?.summaryText, "等待你确认、补充信息或继续执行。")
    XCTAssertEqual(presentation?.sourceText, "Claude Code")
}

func testHighlightedIslandPresentationReturnsNilForNonAttentionSession() {
    let session = makeSession(status: .running)

    XCTAssertNil(HighlightedIslandPresentation(topSession: session))
}

func testHighlightedIslandPresentationUsesRelativeLastActiveTime() {
    let session = makeSession(status: .failed)

    let presentation = HighlightedIslandPresentation(topSession: session)

    XCTAssertEqual(presentation?.timeText, session.relativeLastActiveText)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter UIDisplayFormattingTests
```

Expected: FAIL because `HighlightedIslandPresentation` does not exist yet.

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

    public init?(topSession: TaskSession?) {
        guard let topSession, topSession.status.needsAttention else {
            return nil
        }

        sessionID = topSession.id
        status = topSession.status
        titleText = topSession.title
        summaryText = topSession.compactSessionSubtitle
        sourceText = topSession.sourceCLI.displayName
        timeText = topSession.relativeLastActiveText
        accessibilityLabel = "MacIrland，\(titleText)，\(summaryText)，来自 \(sourceText)"
        accentColor = IslandAccent.color(for: topSession.status)
    }
}
```

Keep `CompactIslandPresentation` unchanged in the same file.

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter UIDisplayFormattingTests
```

Expected: PASS, including the three new highlighted-presentation tests.

- [ ] **Step 5: Commit**

```bash
git add \
  MacIrlandKit/Features/Island/IslandPresentation.swift \
  MacIrlandTests/UIDisplayFormattingTests.swift
git commit -m "test: add highlighted island presentation helpers"
```

### Task 2: Add expanded-card and surface-switching views

**Files:**
- Create: `MacIrlandKit/Features/Island/IslandExpandedCardView.swift`
- Create: `MacIrlandKit/Features/Island/IslandSurfaceView.swift`
- Modify: `MacIrlandKit/DesignSystem/PanelTheme.swift`
- Test: `MacIrlandTests/UIDisplayFormattingTests.swift`

- [ ] **Step 1: Write the failing tests**

Add these tests to `MacIrlandTests/UIDisplayFormattingTests.swift`:

```swift
@MainActor
func testHighlightedIslandPresentationAccessibilityLabelIncludesSource() {
    let session = makeSession(status: .alert)

    let presentation = HighlightedIslandPresentation(topSession: session)

    XCTAssertEqual(
        presentation?.accessibilityLabel,
        "MacIrland，UI refresh，当前会话出现异常，优先查看错误并决定是否重试。，来自 Claude Code"
    )
}

@MainActor
func testHighlightedIslandPresentationUsesStatusAccentColor() {
    let session = makeSession(status: .failed)

    let presentation = HighlightedIslandPresentation(topSession: session)

    XCTAssertEqual(presentation?.accentColor, IslandAccent.color(for: .failed))
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter UIDisplayFormattingTests
```

Expected: FAIL until the expanded-card presentation layer is fully wired.

- [ ] **Step 3: Write minimal implementation**

Create `MacIrlandKit/Features/Island/IslandExpandedCardView.swift`:

```swift
import SwiftUI

public struct IslandExpandedCardView: View {
    let presentation: HighlightedIslandPresentation
    let openPanel: () -> Void
    let dismiss: () -> Void

    public init(
        presentation: HighlightedIslandPresentation,
        openPanel: @escaping () -> Void,
        dismiss: @escaping () -> Void
    ) {
        self.presentation = presentation
        self.openPanel = openPanel
        self.dismiss = dismiss
    }

    public var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: openPanel) {
                VStack(alignment: .leading, spacing: 18) {
                    Spacer(minLength: 0)

                    HStack(alignment: .center, spacing: 14) {
                        StatusSpriteView(status: presentation.status)

                        VStack(alignment: .leading, spacing: 6) {
                            Text(presentation.titleText)
                                .font(.system(size: 17, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)

                            Text(presentation.summaryText)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(MacIrlandPalette.secondaryText)
                                .lineLimit(2)
                        }

                        Spacer(minLength: 16)

                        VStack(alignment: .trailing, spacing: 8) {
                            MetaChip(presentation.sourceText, tint: presentation.accentColor)
                            Text(presentation.timeText)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(MacIrlandPalette.tertiaryText)
                        }
                    }
                }
                .padding(22)
                .frame(width: 860, height: 152, alignment: .bottomLeading)
                .background(MacIrlandPalette.islandSurface, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .strokeBorder(presentation.accentColor.opacity(0.18), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            HStack(spacing: 10) {
                Image(systemName: "speaker.wave.2.fill")
                Image(systemName: "gearshape.fill")
                Button(action: dismiss) {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.plain)
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white.opacity(0.8))
            .padding(18)
        }
        .accessibilityLabel(presentation.accessibilityLabel)
    }
}
```

Create `MacIrlandKit/Features/Island/IslandSurfaceView.swift`:

```swift
import SwiftUI

public enum IslandSurfaceMode: Equatable {
    case compact
    case highlighted(HighlightedIslandPresentation)
}

public struct IslandSurfaceView: View {
    @Bindable var store: TaskStateStore
    let mode: IslandSurfaceMode
    let openPanel: () -> Void
    let dismissHighlight: () -> Void

    public init(
        store: TaskStateStore,
        mode: IslandSurfaceMode,
        openPanel: @escaping () -> Void,
        dismissHighlight: @escaping () -> Void
    ) {
        self.store = store
        self.mode = mode
        self.openPanel = openPanel
        self.dismissHighlight = dismissHighlight
    }

    public var body: some View {
        switch mode {
        case .compact:
            IslandStatusStripView(store: store, action: openPanel)
        case .highlighted(let presentation):
            IslandExpandedCardView(
                presentation: presentation,
                openPanel: openPanel,
                dismiss: dismissHighlight
            )
        }
    }
}
```

Update `MacIrlandKit/DesignSystem/PanelTheme.swift`:

```swift
public extension MacIrlandPalette {
    static let islandChrome = Color.white.opacity(0.8)
    static let islandSubtleBorder = Color.white.opacity(0.06)
}
```

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter UIDisplayFormattingTests
```

Expected: PASS, including the new accessibility-label and accent-color assertions.

- [ ] **Step 5: Commit**

```bash
git add \
  MacIrlandKit/Features/Island/IslandExpandedCardView.swift \
  MacIrlandKit/Features/Island/IslandSurfaceView.swift \
  MacIrlandKit/DesignSystem/PanelTheme.swift \
  MacIrlandTests/UIDisplayFormattingTests.swift
git commit -m "feat: add expanded island card surface"
```

### Task 3: Add coordinator state mode, sizing, and dismiss-reset behavior

**Files:**
- Modify: `MacIrlandApp/App/IslandCoordinator.swift`
- Modify: `MacIrlandApp/App/AppDelegate.swift`
- Test: `MacIrlandTests/AppLaunchSupportTests.swift`

- [ ] **Step 1: Write the failing tests**

Add these tests to `MacIrlandTests/AppLaunchSupportTests.swift`:

```swift
func testIslandCoordinatorTracksSurfaceMode() throws {
    let source = try String(contentsOfFile: "MacIrlandApp/App/IslandCoordinator.swift", encoding: .utf8)

    XCTAssertTrue(source.contains("private var mode: IslandSurfaceMode"))
}

func testIslandCoordinatorStoresDismissedHighlightedSessionID() throws {
    let source = try String(contentsOfFile: "MacIrlandApp/App/IslandCoordinator.swift", encoding: .utf8)

    XCTAssertTrue(source.contains("dismissedHighlightedSessionID"))
}

func testIslandCoordinatorResizesWindowForHighlightedMode() throws {
    let source = try String(contentsOfFile: "MacIrlandApp/App/IslandCoordinator.swift", encoding: .utf8)

    XCTAssertTrue(source.contains("window.setContentSize"))
    XCTAssertTrue(source.contains("CGSize(width: 860, height: 152)"))
    XCTAssertTrue(source.contains("CGSize(width: 520, height: 44)"))
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter AppLaunchSupportTests
```

Expected: FAIL because the coordinator still only knows about the compact strip.

- [ ] **Step 3: Write minimal implementation**

Update `MacIrlandApp/App/IslandCoordinator.swift`:

```swift
private var mode: IslandSurfaceMode = .compact
private var dismissedHighlightedSessionID: TaskSession.ID?

private func recomputeMode() {
    if let highlighted = HighlightedIslandPresentation(topSession: store.topSession),
       highlighted.sessionID != dismissedHighlightedSessionID {
        mode = .highlighted(highlighted)
        window.setContentSize(CGSize(width: 860, height: 152))
    } else {
        mode = .compact
        window.setContentSize(CGSize(width: 520, height: 44))
    }

    window.contentView = NSHostingView(
        rootView: IslandSurfaceView(
            store: store,
            mode: mode,
            openPanel: { [weak self] in self?.openPanel() },
            dismissHighlight: { [weak self] in self?.dismissHighlight() }
        )
    )
    layoutWindow()
}

private func dismissHighlight() {
    if case let .highlighted(presentation) = mode {
        dismissedHighlightedSessionID = presentation.sessionID
    }
    recomputeMode()
}

private func openPanel() {
    action()
    dismissedHighlightedSessionID = nil
    recomputeMode()
}
```

Also reset the dismissal key when the highlighted session changes:

```swift
if let topSession = store.topSession, topSession.id != dismissedHighlightedSessionID {
    // allow the new highlighted session to surface again
}
```

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter AppLaunchSupportTests
```

Expected: PASS, including the new mode/resize/dismiss source tests.

- [ ] **Step 5: Commit**

```bash
git add \
  MacIrlandApp/App/IslandCoordinator.swift \
  MacIrlandTests/AppLaunchSupportTests.swift
git commit -m "feat: add expanded island coordinator state"
```

### Task 4: Wire observation refresh into compact vs highlighted surface transitions

**Files:**
- Modify: `MacIrlandApp/App/IslandCoordinator.swift`
- Modify: `MacIrlandKit/Features/Island/IslandStatusStripView.swift`
- Modify: `MacIrlandApp/App/StatusBarController.swift`
- Test: `MacIrlandTests/AppLaunchSupportTests.swift`

- [ ] **Step 1: Write the failing tests**

Add these tests to `MacIrlandTests/AppLaunchSupportTests.swift`:

```swift
func testIslandCoordinatorHostsIslandSurfaceViewInsteadOfStatusStripOnly() throws {
    let source = try String(contentsOfFile: "MacIrlandApp/App/IslandCoordinator.swift", encoding: .utf8)

    XCTAssertTrue(source.contains("IslandSurfaceView"))
}

func testStatusBarControllerRemainsFallbackAfterExpandedIslandPhase() throws {
    let source = try String(contentsOfFile: "MacIrlandApp/App/StatusBarController.swift", encoding: .utf8)

    XCTAssertTrue(source.contains("fallback"))
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter AppLaunchSupportTests
```

Expected: FAIL because the coordinator still hosts `IslandStatusStripView` directly.

- [ ] **Step 3: Write minimal implementation**

Update the initial `IslandCoordinator` setup so both `init` and `observeStore()` call `recomputeMode()` instead of recreating the compact strip directly.

Keep `MacIrlandKit/Features/Island/IslandStatusStripView.swift` limited to the compact button copy and layout; do not add expanded-card behavior into this file.

Update the `StatusBarController` tooltip so it reads:

```swift
button.toolTip = "\(presentation.accessibilityLabel)。顶部 island 会在高优先级会话时展开，菜单栏入口仍可作为 fallback。"
```

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter AppLaunchSupportTests
```

Expected: PASS, including the new hosting/fallback tests.

- [ ] **Step 5: Commit**

```bash
git add \
  MacIrlandApp/App/IslandCoordinator.swift \
  MacIrlandKit/Features/Island/IslandStatusStripView.swift \
  MacIrlandApp/App/StatusBarController.swift \
  MacIrlandTests/AppLaunchSupportTests.swift
git commit -m "feat: switch island surface between compact and highlighted modes"
```

### Task 5: Verify expanded island behavior and update docs

**Files:**
- Modify: `CLAUDE.md`
- Modify: `docs/superpowers/specs/2026-04-09-island-first-experience-design.md`
- Test: `MacIrlandTests/UIDisplayFormattingTests.swift`
- Test: `MacIrlandTests/AppLaunchSupportTests.swift`

- [ ] **Step 1: Update the repo docs before final verification**

Add this note to `CLAUDE.md`:

```md
- island 当前已具备 compact + expanded 两层形态：常态显示图标、状态词和会话数；高优先级会话会展开成单条任务卡，点击后进入 panel。
- expanded island 当前仍是静态高亮卡，不包含复杂动效、快速动作按钮或自由输入。
```

Update the spec status line in `docs/superpowers/specs/2026-04-09-island-first-experience-design.md`:

```md
- 状态：Phase 2 实施计划已完成，待执行
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

- [ ] **Step 4: Run the dev app and verify the expanded card manually**

Run:

```bash
defaults write com.macirland.app OpenPanelOnLaunch -bool NO
./Scripts/run-dev-app.sh
```

Manual checks:
- With no attention session, the top island stays in compact strip form.
- When a `waitingInput` / `failed` / `alert` session becomes top priority, the island expands into a single-task card.
- The expanded card keeps large empty space and does not turn into a mini panel.
- Clicking the expanded card opens the existing `MacIrland` panel.
- Dismissing the expanded card returns the surface to the compact strip.

- [ ] **Step 5: Commit**

```bash
git add \
  CLAUDE.md \
  docs/superpowers/specs/2026-04-09-island-first-experience-design.md \
  MacIrlandTests/UIDisplayFormattingTests.swift \
  MacIrlandTests/AppLaunchSupportTests.swift
git commit -m "docs: record island-first phase 2 delivery"
```

---

## Self-Review

### Spec coverage
- The plan adds the `expanded single-task card`, which is the highest-value missing piece after Phase 1.
- The plan explicitly keeps quick actions, free-text input, and complex animation out of scope.
- The plan preserves panel as the deeper interaction layer and keeps menu bar/Dock as fallback.

### Placeholder scan
- No placeholder markers remain.
- Each task includes exact file paths, code blocks, commands, and expected outcomes.

### Type consistency
- The plan consistently uses `HighlightedIslandPresentation`, `IslandExpandedCardView`, `IslandSurfaceView`, and `IslandSurfaceMode`.
- `IslandSurfaceMode` is introduced before coordinator tasks depend on it.
- The plan keeps the state machine inside `IslandCoordinator`, rather than spreading it across AppKit and SwiftUI layers.
