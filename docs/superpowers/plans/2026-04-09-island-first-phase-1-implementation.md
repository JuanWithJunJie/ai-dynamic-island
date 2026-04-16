# Island-First Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a real top-anchored compact island/status strip to MacIrland so the app has a continuously visible first-layer experience without opening the panel.

**Architecture:** Keep the existing `TaskStateStore`, panel, and reply/history model intact. Add a new island presentation layer in `MacIrlandKit`, then host it from a dedicated AppKit coordinator that manages a non-panel top overlay window. The existing `StatusBarController` and `PanelCoordinator` stay as fallback navigation; the new island becomes the default first-layer surface.

**Tech Stack:** Swift, SwiftUI, AppKit, XCTest, Swift Package Manager

---

## Planned File Map

- Create: `MacIrlandKit/Features/Island/IslandPresentation.swift`
  - Owns the user-facing compact island/status-strip wording and color mapping.
- Create: `MacIrlandKit/Features/Island/IslandStatusStripView.swift`
  - Owns the top compact island UI for `icon + status word + session count`.
- Create: `MacIrlandApp/App/IslandCoordinator.swift`
  - Owns the top-anchored overlay window, placement, hosting, and click behavior.
- Modify: `MacIrlandApp/App/AppDelegate.swift`
  - Instantiates and retains the new island coordinator and keeps it updated.
- Modify: `MacIrlandApp/App/PanelCoordinator.swift`
  - Exposes a stable `showPanel()` path so both menu bar and island can open the same panel.
- Modify: `MacIrlandApp/App/StatusBarController.swift`
  - Keeps the compact menu bar fallback but no longer carries the burden of being the main visible surface.
- Modify: `MacIrlandKit/DesignSystem/PanelTheme.swift`
  - Adds any new compact-island palette tokens that should be shared rather than hard-coded.
- Modify: `MacIrlandTests/UIDisplayFormattingTests.swift`
  - Covers compact island wording, count formatting, and presentation priority.
- Modify: `MacIrlandTests/AppLaunchSupportTests.swift`
  - Covers app-lifecycle wiring and source-level guarantees around island ownership.
- Modify: `CLAUDE.md`
  - Records the new first-layer experience and the fallback relationship between island, menu bar, Dock, and panel.

---

### Task 1: Add compact-island presentation helpers and tests

**Files:**
- Create: `MacIrlandKit/Features/Island/IslandPresentation.swift`
- Modify: `MacIrlandKit/DesignSystem/DisplayFormatting.swift`
- Test: `MacIrlandTests/UIDisplayFormattingTests.swift`

- [ ] **Step 1: Write the failing tests**

Add these tests to `MacIrlandTests/UIDisplayFormattingTests.swift`:

```swift
func testCompactIslandPresentationUsesIdleStateWhenNoSessionsExist() {
    let summary = AppTaskSummary(runningCount: 0, waitingCount: 0, completedCount: 0, alertCount: 0)

    let presentation = CompactIslandPresentation(summary: summary, topSession: nil)

    XCTAssertEqual(presentation.statusText, "空闲")
    XCTAssertEqual(presentation.countText, "0 个会话")
}

func testCompactIslandPresentationPrefersWaitingStateOverRunning() {
    let session = makeSession(status: .waitingInput)
    let summary = AppTaskSummary(runningCount: 1, waitingCount: 1, completedCount: 0, alertCount: 0)

    let presentation = CompactIslandPresentation(summary: summary, topSession: session)

    XCTAssertEqual(presentation.statusText, "等待处理")
    XCTAssertEqual(presentation.countText, "1 个会话")
}

func testCompactIslandPresentationUsesRunningStateForActiveWork() {
    let session = makeSession(status: .running)
    let summary = AppTaskSummary(runningCount: 2, waitingCount: 0, completedCount: 0, alertCount: 0)

    let presentation = CompactIslandPresentation(summary: summary, topSession: session)

    XCTAssertEqual(presentation.statusText, "运行中")
    XCTAssertEqual(presentation.countText, "2 个会话")
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter UIDisplayFormattingTests
```

Expected: FAIL because `CompactIslandPresentation`, `statusText`, and `countText` do not exist yet.

- [ ] **Step 3: Write minimal implementation**

Create `MacIrlandKit/Features/Island/IslandPresentation.swift` with:

```swift
import SwiftUI

public struct CompactIslandPresentation: Equatable {
    public let statusText: String
    public let countText: String
    public let accessibilityLabel: String
    public let accentColor: Color

    public init(summary: AppTaskSummary, topSession: TaskSession?) {
        if summary.attentionCount > 0 {
            statusText = "等待处理"
            countText = "\(summary.attentionCount) 个会话"
        } else if summary.runningCount > 0 {
            statusText = "运行中"
            countText = "\(summary.runningCount) 个会话"
        } else if summary.completedCount > 0 {
            statusText = "已完成"
            countText = "\(summary.completedCount) 个会话"
        } else {
            statusText = "空闲"
            countText = "0 个会话"
        }

        accessibilityLabel = "MacIrland，\(statusText)，\(countText)"
        accentColor = topSession.map { IslandAccent.color(for: $0.status) } ?? .green
    }
}
```

Update `MacIrlandKit/DesignSystem/DisplayFormatting.swift` so `AppTaskSummary` still exposes `attentionCount`, and add this convenience for the view layer:

```swift
public extension AppTaskSummary {
    var activeSessionCount: Int {
        runningCount + waitingCount + alertCount
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter UIDisplayFormattingTests
```

Expected: PASS, including the three new compact-island presentation tests.

- [ ] **Step 5: Commit**

```bash
git add \
  MacIrlandKit/Features/Island/IslandPresentation.swift \
  MacIrlandKit/DesignSystem/DisplayFormatting.swift \
  MacIrlandTests/UIDisplayFormattingTests.swift
git commit -m "test: add compact island presentation helpers"
```

### Task 2: Add a top-anchored island coordinator and lifecycle tests

**Files:**
- Create: `MacIrlandApp/App/IslandCoordinator.swift`
- Modify: `MacIrlandApp/App/AppDelegate.swift`
- Modify: `MacIrlandApp/App/PanelCoordinator.swift`
- Test: `MacIrlandTests/AppLaunchSupportTests.swift`

- [ ] **Step 1: Write the failing tests**

Add these tests to `MacIrlandTests/AppLaunchSupportTests.swift`:

```swift
func testAppDelegateOwnsIslandCoordinatorForTopLevelSurface() throws {
    let source = try String(contentsOfFile: "MacIrlandApp/App/AppDelegate.swift", encoding: .utf8)

    XCTAssertTrue(source.contains("IslandCoordinator"))
}

func testPanelCoordinatorExposesShowPanelForIslandClicks() throws {
    let source = try String(contentsOfFile: "MacIrlandApp/App/PanelCoordinator.swift", encoding: .utf8)

    XCTAssertTrue(source.contains("func showPanel()"))
}

func testIslandCoordinatorAnchorsWindowNearTopCenter() throws {
    let source = try String(contentsOfFile: "MacIrlandApp/App/IslandCoordinator.swift", encoding: .utf8)

    XCTAssertTrue(source.contains("visibleFrame.midX"))
    XCTAssertTrue(source.contains("visibleFrame.maxY"))
    XCTAssertTrue(source.contains("setFrameOrigin"))
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter AppLaunchSupportTests
```

Expected: FAIL because `IslandCoordinator` and `showPanel()` do not exist yet.

- [ ] **Step 3: Write minimal implementation**

Create `MacIrlandApp/App/IslandCoordinator.swift` with:

```swift
import AppKit
import SwiftUI
import MacIrlandKit

@MainActor
final class IslandCoordinator {
    private let window: NSPanel
    private let store: TaskStateStore
    private let action: () -> Void

    init(store: TaskStateStore, action: @escaping () -> Void) {
        self.store = store
        self.action = action

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 44),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .statusBar
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.ignoresMouseEvents = false
        panel.contentView = NSHostingView(rootView: IslandStatusStripView(store: store, action: action))

        self.window = panel
        layoutWindow()
        panel.orderFrontRegardless()
    }

    func layoutWindow() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let visibleFrame = screen.visibleFrame
        let size = window.frame.size
        let origin = NSPoint(
            x: visibleFrame.midX - (size.width / 2),
            y: visibleFrame.maxY - size.height - 6
        )
        window.setFrameOrigin(origin)
    }
}
```

Update `MacIrlandApp/App/PanelCoordinator.swift`:

```swift
func showPanel() {
    NSApp.activate(ignoringOtherApps: true)
    panel.makeKeyAndOrderFront(nil)
}

func togglePanel() {
    if panel.isVisible {
        panel.orderOut(nil)
    } else {
        showPanel()
    }
}
```

Update `MacIrlandApp/App/AppDelegate.swift` to retain the coordinator:

```swift
private lazy var islandCoordinator = IslandCoordinator(store: store) {
    self.panelCoordinator.showPanel()
}
```

Instantiate it after the launch-mode guard and after activation policy is set:

```swift
NSApp.setActivationPolicy(.regular)
_ = statusBarController
_ = islandCoordinator
openPanelIfRequested()
```

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter AppLaunchSupportTests
```

Expected: PASS, including the new island lifecycle/source tests.

- [ ] **Step 5: Commit**

```bash
git add \
  MacIrlandApp/App/IslandCoordinator.swift \
  MacIrlandApp/App/AppDelegate.swift \
  MacIrlandApp/App/PanelCoordinator.swift \
  MacIrlandTests/AppLaunchSupportTests.swift
git commit -m "feat: add top-anchored island coordinator"
```

### Task 3: Build the compact island/status strip SwiftUI surface

**Files:**
- Create: `MacIrlandKit/Features/Island/IslandStatusStripView.swift`
- Modify: `MacIrlandKit/DesignSystem/PanelTheme.swift`
- Test: `MacIrlandTests/UIDisplayFormattingTests.swift`

- [ ] **Step 1: Write the failing tests**

Add these tests to `MacIrlandTests/UIDisplayFormattingTests.swift`:

```swift
@MainActor
func testCompactIslandPresentationAccessibilityLabelIncludesStatusAndCount() {
    let session = makeSession(status: .running)
    let summary = AppTaskSummary(runningCount: 1, waitingCount: 0, completedCount: 0, alertCount: 0)

    let presentation = CompactIslandPresentation(summary: summary, topSession: session)

    XCTAssertEqual(presentation.accessibilityLabel, "MacIrland，运行中，1 个会话")
}

@MainActor
func testCompactIslandPresentationUsesAttentionAccentForWaitingSession() {
    let session = makeSession(status: .waitingInput)
    let summary = AppTaskSummary(runningCount: 0, waitingCount: 1, completedCount: 0, alertCount: 0)

    let presentation = CompactIslandPresentation(summary: summary, topSession: session)

    XCTAssertEqual(presentation.statusText, "等待处理")
    XCTAssertEqual(presentation.accentColor, IslandAccent.color(for: .waitingInput))
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter UIDisplayFormattingTests
```

Expected: FAIL because the compact island view contract is incomplete.

- [ ] **Step 3: Write minimal implementation**

Create `MacIrlandKit/Features/Island/IslandStatusStripView.swift` with:

```swift
import SwiftUI

public struct IslandStatusStripView: View {
    @Bindable private var store: TaskStateStore
    private let action: () -> Void

    public init(store: TaskStateStore, action: @escaping () -> Void) {
        self.store = store
        self.action = action
    }

    public var body: some View {
        let presentation = CompactIslandPresentation(summary: store.summary, topSession: store.topSession)

        Button(action: action) {
            HStack(spacing: 10) {
                StatusSpriteView(status: store.topSession?.status ?? .completed)
                Text(presentation.statusText)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Spacer(minLength: 12)
                Text(presentation.countText)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.86))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .frame(width: 520, alignment: .leading)
            .background(MacIrlandPalette.surface, in: Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(presentation.accentColor.opacity(0.28), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(presentation.accessibilityLabel)
    }
}
```

Update `MacIrlandKit/DesignSystem/PanelTheme.swift` with this shared token:

```swift
public extension MacIrlandPalette {
    static let islandSurface = Color.black.opacity(0.94)
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
  MacIrlandKit/Features/Island/IslandStatusStripView.swift \
  MacIrlandKit/DesignSystem/PanelTheme.swift \
  MacIrlandTests/UIDisplayFormattingTests.swift
git commit -m "feat: add compact island status strip"
```

### Task 4: Wire island updates, placement refresh, and panel handoff

**Files:**
- Modify: `MacIrlandApp/App/IslandCoordinator.swift`
- Modify: `MacIrlandApp/App/AppDelegate.swift`
- Modify: `MacIrlandApp/App/StatusBarController.swift`
- Test: `MacIrlandTests/AppLaunchSupportTests.swift`

- [ ] **Step 1: Write the failing tests**

Add these tests to `MacIrlandTests/AppLaunchSupportTests.swift`:

```swift
func testIslandCoordinatorObservesStoreSummaryAndTopSession() throws {
    let source = try String(contentsOfFile: "MacIrlandApp/App/IslandCoordinator.swift", encoding: .utf8)

    XCTAssertTrue(source.contains("withObservationTracking"))
    XCTAssertTrue(source.contains("_ = store.summary"))
    XCTAssertTrue(source.contains("_ = store.topSession"))
}

func testAppDelegateRoutesIslandTapToShowPanel() throws {
    let source = try String(contentsOfFile: "MacIrlandApp/App/AppDelegate.swift", encoding: .utf8)

    XCTAssertTrue(source.contains("self.panelCoordinator.showPanel()"))
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter AppLaunchSupportTests
```

Expected: FAIL because the island coordinator does not yet observe store changes or explicitly route taps to `showPanel()`.

- [ ] **Step 3: Write minimal implementation**

Update `MacIrlandApp/App/IslandCoordinator.swift` to re-layout and refresh on store changes:

```swift
import Observation

private func observeStore() {
    withObservationTracking {
        _ = store.summary
        _ = store.topSession
    } onChange: { [weak self] in
        DispatchQueue.main.async {
            self?.window.contentView = NSHostingView(
                rootView: IslandStatusStripView(store: self?.store ?? store, action: self?.action ?? {})
            )
            self?.layoutWindow()
            self?.observeStore()
        }
    }
}
```

Call `observeStore()` at the end of `init`.

Update `AppDelegate` closure wiring to use `showPanel()` explicitly:

```swift
private lazy var islandCoordinator = IslandCoordinator(store: store) {
    self.panelCoordinator.showPanel()
}
```

Keep `StatusBarController` as fallback-only UI, but make its tooltip acknowledge the primary island surface:

```swift
button.toolTip = "\(presentation.accessibilityLabel)。顶部状态条可直接打开主面板。"
```

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter AppLaunchSupportTests
```

Expected: PASS, including the new island observation/routing tests.

- [ ] **Step 5: Commit**

```bash
git add \
  MacIrlandApp/App/IslandCoordinator.swift \
  MacIrlandApp/App/AppDelegate.swift \
  MacIrlandApp/App/StatusBarController.swift \
  MacIrlandTests/AppLaunchSupportTests.swift
git commit -m "feat: wire island updates and panel handoff"
```

### Task 5: Verify the compact island live and update project docs

**Files:**
- Modify: `CLAUDE.md`
- Modify: `docs/superpowers/specs/2026-04-09-island-first-experience-design.md`
- Test: `MacIrlandTests/AppLaunchSupportTests.swift`
- Test: `MacIrlandTests/UIDisplayFormattingTests.swift`

- [ ] **Step 1: Add the repo note before verification**

Update `CLAUDE.md` with a short “island-first phase 1” note that says:

```md
- 已新增顶部 compact island / status strip：默认显示图标、状态词和会话数；点击后可直接打开主 panel。
- 当前 menu bar 与 Dock 仍然保留，作为 island 之外的保底入口。
```

Also update the spec status line in `docs/superpowers/specs/2026-04-09-island-first-experience-design.md`:

```md
- 状态：设计已确认，Phase 1 实施计划已完成
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

- [ ] **Step 4: Run the dev app and verify the new surface manually**

Run:

```bash
defaults write com.macirland.app OpenPanelOnLaunch -bool NO
./Scripts/run-dev-app.sh
```

Manual checks:
- The top compact island is visible near the top center of the active screen.
- It shows `图标 + 状态词 + 会话数`, not just a plain icon.
- Clicking the compact island opens the existing `MacIrland` panel.
- The menu bar icon and Dock icon still exist as fallback entry points.

- [ ] **Step 5: Commit**

```bash
git add \
  CLAUDE.md \
  docs/superpowers/specs/2026-04-09-island-first-experience-design.md \
  MacIrlandTests/AppLaunchSupportTests.swift \
  MacIrlandTests/UIDisplayFormattingTests.swift
git commit -m "docs: record island-first phase 1 delivery"
```

---

## Self-Review

### Spec coverage
- `compact island / status strip` is covered by Task 1 and Task 3.
- `top-anchored standalone surface instead of relying on NSStatusItem` is covered by Task 2.
- `island -> panel` click handoff is covered by Task 2 and Task 4.
- `keep menu bar and Dock as fallback` is covered by Task 4 and Task 5.
- `Phase 1 only, no expanded single-task card yet` is preserved because no task introduces expanded-card layout, quick actions in island, or new diagnostics surfaces.

### Placeholder scan
- No placeholder markers remain.
- Every task contains exact file paths, code blocks, commands, and expected outcomes.

### Type consistency
- The plan consistently uses `CompactIslandPresentation`, `IslandStatusStripView`, and `IslandCoordinator`.
- `PanelCoordinator.showPanel()` is introduced before later tasks depend on it.
- The plan keeps `TaskStateStore` read-only from the island layer and does not invent new state sources beyond `summary` and `topSession`.
