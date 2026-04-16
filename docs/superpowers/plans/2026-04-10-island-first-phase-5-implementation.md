# Island-First Phase 5 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Further demote the panel into a true second-layer detail space so the island remains the primary experience and the panel feels quieter, more contextual, and less dashboard-like.

**Architecture:** Keep the island states, quick action flow, and existing panel model intact. Refine the panel presentation layer so it opens around the currently highlighted or top-priority session, reduces duplicated global summary content, and pushes diagnostics and secondary navigation further into the background. Do not add new business logic, data sources, or reply capabilities in this phase.

**Tech Stack:** Swift, SwiftUI, AppKit, XCTest, Swift Package Manager

---

## Planned File Map

- Modify: `MacIrlandApp/App/PanelCoordinator.swift`
  - Expose a stable “open panel focused on current top session” path that island flows can rely on.
- Modify: `MacIrlandApp/App/AppDelegate.swift`
  - Route island-driven panel opens through the new focused-open API.
- Modify: `MacIrlandKit/Features/Panel/PanelView.swift`
  - Reduce first-screen global summary noise and reinforce “current task workspace first, everything else second”.
- Modify: `MacIrlandKit/Features/Panel/SessionPickerView.swift`
  - Push the session list further toward lightweight navigation instead of card-like feed.
- Modify: `MacIrlandKit/Features/Panel/SessionDetailView.swift`
  - Keep the main task workspace crisp and remove any leftover duplicated context that the island already surfaces.
- Modify: `MacIrlandKit/Features/Panel/PanelPresentation.swift`
  - Add small helper properties for panel copy and priority focus if needed.
- Modify: `MacIrlandTests/UIDisplayFormattingTests.swift`
  - Cover the new panel copy and emphasis behavior.
- Modify: `MacIrlandTests/AppLaunchSupportTests.swift`
  - Cover the source-level coordinator routing into the focused-open panel path.
- Modify: `CLAUDE.md`
  - Record that the panel has been further demoted to a contextual second layer.
  - Final execution report written after implementation is complete.

---

### Task 1: Add focused-open panel coordinator path and tests

**Files:**
- Modify: `MacIrlandApp/App/PanelCoordinator.swift`
- Modify: `MacIrlandApp/App/AppDelegate.swift`
- Modify: `MacIrlandTests/AppLaunchSupportTests.swift`

- [ ] **Step 1: Write the failing tests**

Add these tests to `MacIrlandTests/AppLaunchSupportTests.swift`:

```swift
func testPanelCoordinatorExposesShowPanelFocusedOnTopSession() throws {
    let source = try String(contentsOfFile: "MacIrlandApp/App/PanelCoordinator.swift", encoding: .utf8)

    XCTAssertTrue(source.contains("func showPanelSelectingTopSession()"))
}

func testAppDelegateRoutesIslandOpenThroughFocusedPanelPath() throws {
    let source = try String(contentsOfFile: "MacIrlandApp/App/AppDelegate.swift", encoding: .utf8)

    XCTAssertTrue(source.contains("self.panelCoordinator.showPanelSelectingTopSession()"))
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter AppLaunchSupportTests
```

Expected: FAIL because the focused-open panel API does not exist yet.

- [ ] **Step 3: Write minimal implementation**

Update `MacIrlandApp/App/PanelCoordinator.swift`:

```swift
private let store: TaskStateStore

init(store: TaskStateStore) {
    self.store = store
    let panel = NSPanel(
        contentRect: NSRect(x: 0, y: 0, width: 760, height: 820),
        styleMask: [.titled, .closable, .fullSizeContentView],
        backing: .buffered,
        defer: false
    )
    // existing setup
}

func showPanelSelectingTopSession() {
    if let topSession = store.topSession {
        store.selectSession(topSession)
    }
    showPanel()
}
```

Keep the existing `showPanel()` and `togglePanel()` behavior intact.

Update `MacIrlandApp/App/AppDelegate.swift`:

```swift
private lazy var islandCoordinator = IslandCoordinator(store: store) {
    self.panelCoordinator.showPanelSelectingTopSession()
}
```

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter AppLaunchSupportTests
```

Expected: PASS, including the new focused-open panel routing tests.

- [ ] **Step 5: Commit**

```bash
git add \
  MacIrlandApp/App/PanelCoordinator.swift \
  MacIrlandApp/App/AppDelegate.swift \
  MacIrlandTests/AppLaunchSupportTests.swift
git commit -m "feat: focus panel on top session when opened from island"
```

### Task 2: Reduce header/dashboard noise in the panel

**Files:**
- Modify: `MacIrlandKit/Features/Panel/PanelView.swift`
- Modify: `MacIrlandTests/UIDisplayFormattingTests.swift`

- [ ] **Step 1: Write the failing tests**

Add these tests to `MacIrlandTests/UIDisplayFormattingTests.swift`:

```swift
@MainActor
func testPanelHeaderUsesSingleSentenceSummaryInsteadOfMultipleDashboardChips() throws {
    let source = try String(contentsOfFile: "MacIrlandKit/Features/Panel/PanelView.swift", encoding: .utf8)

    XCTAssertFalse(source.contains("FlowChips"))
}

func testPanelHeaderSubtitleStaysFocusedOnCurrentWorkInsteadOfGlobalCounts() {
    let session = makeSession(status: .waitingInput)

    XCTAssertEqual(session.compactSessionSubtitle, "等待你确认、补充信息或继续执行。")
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter UIDisplayFormattingTests
```

Expected: FAIL because the panel header still carries dashboard-style chip content.

- [ ] **Step 3: Write minimal implementation**

Update `MacIrlandKit/Features/Panel/PanelView.swift` so `PanelHeaderView` becomes a quieter header:

```swift
private struct PanelHeaderView: View {
    let summary: AppTaskSummary
    let topSession: TaskSession?
    let capabilityStatus: CapabilityStatus
    let onRefresh: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text("MacIrland")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(topSession?.compactSessionSubtitle ?? "这里是 island 的二级详情层，用来继续处理当前会话。")
                    .font(.footnote)
                    .foregroundStyle(MacIrlandPalette.secondaryText)
                    .lineLimit(2)
            }

            Spacer()

            Button(action: onRefresh) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.92))
                    .frame(width: 34, height: 34)
                    .background(MacIrlandPalette.surfaceMuted, in: Circle())
                    .overlay(Circle().strokeBorder(MacIrlandPalette.border, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }
}
```

Remove the `FlowChips` usage from the header and delete the now-unused helper if the compiler reports it unused.

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter UIDisplayFormattingTests
```

Expected: PASS, including the header-noise regression test.

- [ ] **Step 5: Commit**

```bash
git add \
  MacIrlandKit/Features/Panel/PanelView.swift \
  MacIrlandTests/UIDisplayFormattingTests.swift
git commit -m "refactor: quiet panel header for island-first flow"
```

### Task 3: Push session list further into background navigation

**Files:**
- Modify: `MacIrlandKit/Features/Panel/SessionPickerView.swift`
- Modify: `MacIrlandKit/Features/Panel/PanelView.swift`
- Modify: `MacIrlandTests/UIDisplayFormattingTests.swift`

- [ ] **Step 1: Write the failing tests**

Add these tests to `MacIrlandTests/UIDisplayFormattingTests.swift`:

```swift
func testCompactSessionSubtitleStillDrivesSessionListCopy() {
    let session = makeSession(status: .running)

    XCTAssertEqual(session.compactSessionSubtitle, "Refreshing the panel UI.")
}

@MainActor
func testPanelUsesSubduedCardToneForSessionList() throws {
    let source = try String(contentsOfFile: "MacIrlandKit/Features/Panel/PanelView.swift", encoding: .utf8)

    XCTAssertTrue(source.contains("PanelCard(tone: .subdued, padding: 16)"))
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter UIDisplayFormattingTests
```

Expected: FAIL until the session list is clearly treated as secondary navigation.

- [ ] **Step 3: Write minimal implementation**

Update `MacIrlandKit/Features/Panel/SessionPickerView.swift` so each row stays lightweight:

```swift
- keep title
- keep compact subtitle
- keep one trailing state cue
- remove any extra visual emphasis that makes the list compete with the main workspace
```

If needed, reduce row padding and use a flatter background/selection treatment so the list reads like navigation rather than feed cards.

Keep `MacIrlandKit/Features/Panel/PanelView.swift` session list section in a subdued card tone and do not move it above the main workspace.

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter UIDisplayFormattingTests
```

Expected: PASS for the session-list emphasis tests.

- [ ] **Step 5: Commit**

```bash
git add \
  MacIrlandKit/Features/Panel/SessionPickerView.swift \
  MacIrlandKit/Features/Panel/PanelView.swift \
  MacIrlandTests/UIDisplayFormattingTests.swift
git commit -m "refactor: demote session list to background navigation"
```

### Task 4: Further demote diagnostics and reinforce the panel as a detail layer

**Files:**
- Modify: `MacIrlandKit/Features/Panel/PanelView.swift`
- Modify: `MacIrlandTests/UIDisplayFormattingTests.swift`

- [ ] **Step 1: Write the failing tests**

Add these tests to `MacIrlandTests/UIDisplayFormattingTests.swift`:

```swift
func testDiagnosticsSummaryStillUsesBlockedExplanationWhenNeeded() {
    let blocked = CapabilityStatus(
        accessibilityGranted: true,
        localOnlyProcessing: true,
        explanation: "未授权自动化",
        observationBlocked: true
    )

    XCTAssertEqual(blocked.panelDiagnosticsSummary, "终端读取失败，展开诊断查看权限或识别问题。")
}

@MainActor
func testPanelEmptyWorkspaceCopyDescribesSecondLayerRole() throws {
    let source = try String(contentsOfFile: "MacIrlandKit/Features/Panel/PanelView.swift", encoding: .utf8)

    XCTAssertTrue(source.contains("这里是 island 的二级详情层"))
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter UIDisplayFormattingTests
```

Expected: FAIL until the empty-state and panel-role copy are updated.

- [ ] **Step 3: Write minimal implementation**

Update `MacIrlandKit/Features/Panel/PanelView.swift`:

```swift
private struct EmptyWorkspaceView: View {
    let emptyStateMessage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            PanelSectionHeader("主工作区", subtitle: "这里是 island 的二级详情层，用来继续处理当前会话。")

            Text("还没有可处理的会话")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            Text(emptyStateMessage)
                .font(.subheadline)
                .foregroundStyle(MacIrlandPalette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
```

Keep diagnostics as a collapsed disclosure below the session list; do not move it upward or add new summary chips around it.

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter UIDisplayFormattingTests
```

Expected: PASS, including the second-layer panel copy test.

- [ ] **Step 5: Commit**

```bash
git add \
  MacIrlandKit/Features/Panel/PanelView.swift \
  MacIrlandTests/UIDisplayFormattingTests.swift
git commit -m "refactor: reinforce panel as second layer"
```

### Task 5: Verify the quieter panel and write the execution report

**Files:**
- Modify: `CLAUDE.md`
- Modify: `docs/superpowers/specs/2026-04-09-island-first-experience-design.md`
- Test: `MacIrlandTests/UIDisplayFormattingTests.swift`
- Test: `MacIrlandTests/AppLaunchSupportTests.swift`

- [ ] **Step 1: Update docs before final verification**

Add this note to `CLAUDE.md`:

```md
- panel 已进一步退为 island 的二级详情层：打开时默认聚焦当前顶层会话，header 更安静，session 列表和 diagnostics 都进一步降权。
```

Update the spec status line in `docs/superpowers/specs/2026-04-09-island-first-experience-design.md`:

```md
- 状态：Phase 5 实施计划已完成，待执行
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

- [ ] **Step 4: Run the dev app and verify the panel role manually**

Run:

```bash
defaults write com.macirland.app OpenPanelOnLaunch -bool NO
./Scripts/run-dev-app.sh
```

Manual checks:
- Opening the panel from the island focuses the current top session instead of a stale selection.
- The header no longer looks like a dashboard summary bar.
- The main workspace remains the visual center.
- The session list reads like supporting navigation, not a competing content feed.
- Diagnostics stays clearly secondary unless blocked or manually expanded.

- [ ] **Step 5: Write the execution report**


```md
# Island-First Phase 5 执行报告

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
- what changed in panel focus, header, session list, and diagnostics hierarchy
- whether the execution deviated from the plan

- [ ] **Step 6: Commit**

```bash
git add \
  CLAUDE.md \
  docs/superpowers/specs/2026-04-09-island-first-experience-design.md \
  MacIrlandTests/UIDisplayFormattingTests.swift \
  MacIrlandTests/AppLaunchSupportTests.swift
git commit -m "docs: record island-first phase 5 delivery"
```

---

## Self-Review

### Spec coverage
- The plan implements the other recommended next slice from the Phase 3 report: pushing the panel further into a second-layer role.
- The plan keeps the island as the primary experience and does not re-expand the panel into a dashboard.
- The plan does not add new reply capability or deeper engine changes.

### Placeholder scan
- No placeholder markers remain.
- Each task includes exact file paths, code blocks, commands, and expected outcomes.

### Type consistency
- The plan consistently uses `showPanelSelectingTopSession()` as the island-to-panel handoff.
- The plan keeps panel emphasis changes inside `PanelView`, `SessionPickerView`, and small presentation helpers rather than scattering role logic across the codebase.
