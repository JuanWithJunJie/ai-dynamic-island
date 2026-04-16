# Notch-Anchored Island Auto-Refresh Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 MacIrland 的 island 贴近刘海顶部挂靠，删除 panel 手动刷新按钮，改成固定 1 秒自动刷新，并把 panel 收成更接近竞品体量的紧凑二级详情层。

**Architecture:** 本轮不改变 island-first 主形态，而是在现有架构上补三件事：由 App 层持有统一 refresh scheduler；由 `IslandCoordinator` 改成基于屏幕顶边的 notch-anchored 定位；由 `PanelCoordinator + PanelView + SessionDetailView` 一起把 panel 缩成更轻的 detail sheet。刷新是应用级能力，不能散落在 view 内部。

**Tech Stack:** SwiftUI, AppKit `NSPanel`, `TaskStateStore`, `IslandCoordinator`, `PanelCoordinator`, XCTest

---

## File Structure

### Create
- `MacIrlandApp/App/RefreshCoordinator.swift`

### Modify
- `MacIrlandApp/App/AppDelegate.swift`
- `MacIrlandApp/App/IslandCoordinator.swift`
- `MacIrlandApp/App/PanelCoordinator.swift`
- `MacIrlandApp/App/SettingsView.swift`
- `MacIrlandKit/Features/Panel/PanelView.swift`
- `MacIrlandKit/Features/Panel/SessionDetailView.swift`
- `MacIrlandKit/Features/Panel/SessionPickerView.swift`
- `MacIrlandTests/AppLaunchSupportTests.swift`
- `MacIrlandTests/UIDisplayFormattingTests.swift`
- `CLAUDE.md`

---

### Task 1: Add app-level 1-second refresh scheduler

**Files:**
- Create: `MacIrlandApp/App/RefreshCoordinator.swift`
- Modify: `MacIrlandApp/App/AppDelegate.swift`
- Modify: `MacIrlandApp/App/SettingsView.swift`
- Test: `MacIrlandTests/AppLaunchSupportTests.swift`

- [ ] **Step 1: Write the failing tests**

Add source-level tests that assert:
- `AppDelegate` owns a refresh coordinator
- refresh interval is fixed at `1.0`
- scheduler starts during app launch
- `SettingsView` no longer contains a manual refresh button

Test snippets to add in `MacIrlandTests/AppLaunchSupportTests.swift`:

```swift
func testAppDelegateOwnsRefreshCoordinatorForAppWidePolling() throws {
    let source = try String(contentsOfFile: appDelegatePath)
    XCTAssertTrue(source.contains("private lazy var refreshCoordinator"))
}

func testRefreshCoordinatorUsesOneSecondInterval() throws {
    let source = try String(contentsOfFile: refreshCoordinatorPath)
    XCTAssertTrue(source.contains("interval: TimeInterval = 1.0"))
}

func testAppDelegateStartsRefreshCoordinatorAtLaunch() throws {
    let source = try String(contentsOfFile: appDelegatePath)
    XCTAssertTrue(source.contains("refreshCoordinator.start()"))
}

func testSettingsViewNoLongerShowsManualRefreshButton() throws {
    let source = try String(contentsOfFile: settingsViewPath)
    XCTAssertFalse(source.contains("Button(\"刷新状态\")"))
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run:
```bash
swift test --filter AppLaunchSupportTests
```

Expected: FAIL on missing `RefreshCoordinator` and launch/start wiring.

- [ ] **Step 3: Write the minimal implementation**

Create `MacIrlandApp/App/RefreshCoordinator.swift`:

```swift
import Foundation
import MacIrlandKit

@MainActor
final class RefreshCoordinator {
    private let store: TaskStateStore
    private let interval: TimeInterval
    private var timer: Timer?

    init(store: TaskStateStore, interval: TimeInterval = 1.0) {
        self.store = store
        self.interval = interval
    }

    func start() {
        stop()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.store.refresh()
        }
        timer?.tolerance = 0.2
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    deinit {
        timer?.invalidate()
    }
}
```

Update `MacIrlandApp/App/AppDelegate.swift`:

```swift
private lazy var refreshCoordinator = RefreshCoordinator(store: store)
```

and in `applicationDidFinishLaunching`:

```swift
refreshCoordinator.start()
```

Update `MacIrlandApp/App/SettingsView.swift` by deleting:

```swift
Button("刷新状态") {
    viewModel.refresh()
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run:
```bash
swift test --filter AppLaunchSupportTests
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add MacIrlandApp/App/RefreshCoordinator.swift MacIrlandApp/App/AppDelegate.swift MacIrlandApp/App/SettingsView.swift MacIrlandTests/AppLaunchSupportTests.swift
git commit -m "feat: add app-wide auto refresh scheduler"
```

---

### Task 2: Re-anchor the island to the top screen edge

**Files:**
- Modify: `MacIrlandApp/App/IslandCoordinator.swift`
- Test: `MacIrlandTests/AppLaunchSupportTests.swift`

- [ ] **Step 1: Write the failing tests**

Add source-level tests asserting:
- layout uses `screen.frame` instead of `visibleFrame`
- there is a dedicated top inset constant
- island no longer subtracts the old `6` point gap from `visibleFrame.maxY`

Test snippets:

```swift
func testIslandCoordinatorAnchorsAgainstFullScreenFrame() throws {
    let source = try String(contentsOfFile: islandCoordinatorPath)
    XCTAssertTrue(source.contains("let screenFrame = screen.frame"))
    XCTAssertFalse(source.contains("let visibleFrame = screen.visibleFrame"))
}

func testIslandCoordinatorDefinesSmallTopAnchorInset() throws {
    let source = try String(contentsOfFile: islandCoordinatorPath)
    XCTAssertTrue(source.contains("topAnchorInset"))
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run:
```bash
swift test --filter AppLaunchSupportTests
```

Expected: FAIL on missing `screenFrame` / `topAnchorInset`.

- [ ] **Step 3: Write the minimal implementation**

Update `MacIrlandApp/App/IslandCoordinator.swift` to centralize top anchoring:

```swift
private let topAnchorInset: CGFloat = 1
```

and in `layoutWindow()`:

```swift
let screenFrame = screen.frame
let size = window.frame.size
let origin = NSPoint(
    x: screenFrame.midX - (size.width / 2),
    y: screenFrame.maxY - size.height - topAnchorInset
)
window.setFrameOrigin(origin)
```

Do not add notch-model-specific branching. Keep one shared top-edge rule for compact and highlighted modes.

- [ ] **Step 4: Run the tests to verify they pass**

Run:
```bash
swift test --filter AppLaunchSupportTests
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add MacIrlandApp/App/IslandCoordinator.swift MacIrlandTests/AppLaunchSupportTests.swift
git commit -m "feat: anchor island near notch top edge"
```

---

### Task 3: Remove manual refresh UI and compact the panel shell

**Files:**
- Modify: `MacIrlandApp/App/PanelCoordinator.swift`
- Modify: `MacIrlandKit/Features/Panel/PanelView.swift`
- Test: `MacIrlandTests/UIDisplayFormattingTests.swift`
- Test: `MacIrlandTests/AppLaunchSupportTests.swift`

- [ ] **Step 1: Write the failing tests**

Add tests asserting:
- panel size constants move toward `640 x 560`
- `PanelHeaderView` no longer accepts `onRefresh`
- `PanelHeaderView` no longer renders `arrow.clockwise`
- empty-state copy no longer says `点击右上角刷新`

Test snippets:

```swift
func testPanelCoordinatorUsesCompactDetailSheetSize() throws {
    let source = try String(contentsOfFile: panelCoordinatorPath)
    XCTAssertTrue(source.contains("width: 640"))
    XCTAssertTrue(source.contains("height: 560"))
}

func testPanelHeaderNoLongerRendersRefreshButton() throws {
    let source = try String(contentsOfFile: panelViewPath)
    XCTAssertFalse(source.contains("arrow.clockwise"))
    XCTAssertFalse(source.contains("onRefresh"))
}

func testBlockedEmptyStateNoLongerReferencesManualRefresh() throws {
    let source = try String(contentsOfFile: panelViewPath)
    XCTAssertFalse(source.contains("点击右上角刷新"))
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run:
```bash
swift test --filter AppLaunchSupportTests
swift test --filter UIDisplayFormattingTests
```

Expected: FAIL on current large size and refresh button references.

- [ ] **Step 3: Write the minimal implementation**

Update `MacIrlandApp/App/PanelCoordinator.swift`:

```swift
contentRect: NSRect(x: 0, y: 0, width: 640, height: 560)
```

Update `MacIrlandKit/Features/Panel/PanelView.swift`:
- remove `onRefresh` from `PanelHeaderView`
- delete the refresh button block entirely
- shrink shell spacing/padding:

```swift
VStack(alignment: .leading, spacing: 12)
...
.padding(18)
...
.frame(minWidth: 640, minHeight: 560)
```

Update blocked empty-state copy:

```swift
return "当前没有成功读取到 Claude Code 会话。请确认 Terminal / iTerm 自动化权限已授权，系统会在下一轮自动刷新时重试。"
```

- [ ] **Step 4: Run the tests to verify they pass**

Run:
```bash
swift test --filter AppLaunchSupportTests
swift test --filter UIDisplayFormattingTests
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add MacIrlandApp/App/PanelCoordinator.swift MacIrlandKit/Features/Panel/PanelView.swift MacIrlandTests/AppLaunchSupportTests.swift MacIrlandTests/UIDisplayFormattingTests.swift
git commit -m "feat: compact panel shell and remove manual refresh"
```

---

### Task 4: Compress the panel’s first-screen content density

**Files:**
- Modify: `MacIrlandKit/Features/Panel/SessionDetailView.swift`
- Modify: `MacIrlandKit/Features/Panel/SessionPickerView.swift`
- Modify: `MacIrlandKit/Features/Panel/PanelView.swift`
- Test: `MacIrlandTests/UIDisplayFormattingTests.swift`

- [ ] **Step 1: Write the failing tests**

Add tests asserting:
- timeline preview is reduced to two items
- free text is no longer always fully expanded in the first screen
- session list is clearly secondary/collapsed language

Suggested test snippets:

```swift
func testSessionDetailTimelinePreviewEntriesDefaultToNewestTwoItems() throws {
    let source = try String(contentsOfFile: sessionDetailViewPath)
    XCTAssertTrue(source.contains("prefix(2)") || source.contains("newestTwo"))
}

func testSessionDetailFreeInputUsesCollapsedDisclosure() throws {
    let source = try String(contentsOfFile: sessionDetailViewPath)
    XCTAssertTrue(source.contains("DisclosureGroup"))
}

func testSessionPickerUsesSecondaryNavigationCopy() throws {
    let source = try String(contentsOfFile: panelViewPath)
    XCTAssertTrue(source.contains("其他会话") || source.contains("更多会话"))
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run:
```bash
swift test --filter UIDisplayFormattingTests
```

Expected: FAIL.

- [ ] **Step 3: Write the minimal implementation**

Update `MacIrlandKit/Features/Panel/SessionDetailView.swift`:
- reduce default timeline preview from 3 items to 2
- wrap free text section in a collapsed `DisclosureGroup`
- keep quick actions visible, but do not add more buttons

Suggested shape:

```swift
@State private var freeInputExpanded = false
```

and:

```swift
DisclosureGroup("自由输入", isExpanded: $freeInputExpanded) {
    ...
}
```

Update timeline helper to show only 2:

```swift
session.timelinePreviewEntries(limit: 2)
```

or equivalent minimal implementation in the existing helper layer.

Update `MacIrlandKit/Features/Panel/PanelView.swift` / `SessionPickerView.swift` copy so the session list reads as secondary navigation, e.g. `其他会话`.

- [ ] **Step 4: Run the tests to verify they pass**

Run:
```bash
swift test --filter UIDisplayFormattingTests
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add MacIrlandKit/Features/Panel/SessionDetailView.swift MacIrlandKit/Features/Panel/SessionPickerView.swift MacIrlandKit/Features/Panel/PanelView.swift MacIrlandTests/UIDisplayFormattingTests.swift
git commit -m "feat: compress panel first-screen density"
```

---

### Task 5: Verify the notch-anchored auto-refresh experience and document it

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Run full verification**

Run:
```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland"
swift build --package-path "/Users/lijunjie/Documents/AIproject/macirland"
```

Expected: full suite passes and build succeeds.

- [ ] **Step 2: Launch the app for a real experience pass**

Run:
```bash
cd /Users/lijunjie/Documents/AIproject/macirland
./Scripts/run-dev-app.sh
```

Verify:
- island appears closer to the top edge
- panel opens without refresh button
- panel feels noticeably smaller
- waiting a few seconds causes automatic refresh without user interaction

- [ ] **Step 3: Update docs**

Update `CLAUDE.md` to record:
- notch-anchored island positioning
- fixed 1s app-level auto refresh
- panel compacting and removed refresh button

- [ ] **Step 4: Write the execution report**

Write:

Include:
- objective recap
- changed files
- task-by-task verification
- behavior notes
- remaining risks (especially 1s polling cost)

- [ ] **Step 5: Commit**

```bash
git commit -m "docs: record notch-anchored auto-refresh rollout"
```

---

## Self-Review

### 1. Spec coverage
- 顶部挂靠定位：Task 2
- 固定 1 秒自动刷新：Task 1
- 删除刷新按钮：Task 3
- panel 明显缩小并减重：Task 3 + Task 4
- 文案不再依赖手动刷新：Task 3
- 实机验证：Task 5

### 2. Placeholder scan
- 无 TBD/TODO
- 每个 task 都有明确文件、命令和最小实现方向

### 3. Type consistency
- `RefreshCoordinator` 为新建应用级协调器
- `TaskStateStore.refresh()` 仍是统一刷新入口
- `PanelCoordinator` 负责窗口尺寸
- `IslandCoordinator` 负责顶部位置

---

Plan complete and saved to `docs/superpowers/plans/2026-04-10-notch-anchored-island-auto-refresh-implementation.md`. Two execution options:

**1. Subagent-Driven (recommended)** - 我按任务逐个派发子代理实现，并在每个任务后 review

**2. Inline Execution** - 我在当前会话里直接按计划开始实现

Which approach?
