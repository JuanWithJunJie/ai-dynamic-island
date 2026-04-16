# Panel Simplification Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the MacIrland panel into an intervention-first workspace that foregrounds the active session, quick actions, and reply input while removing or collapsing non-essential overview and diagnostics content.

**Architecture:** Keep the existing `TaskStateStore` and session models intact, and shrink the UI by introducing a small panel-presentation helper layer. Refactor `PanelView` into a minimal header + primary workspace + compact session list + collapsible diagnostics flow, with tests focused on the new formatting and default visibility behavior.

**Tech Stack:** Swift, SwiftUI, AppKit, XCTest, Swift Package Manager

---

### Task 1: Add panel-presentation helpers and tests

**Files:**
- Create: `MacIrlandKit/Features/Panel/PanelPresentation.swift`
- Modify: `MacIrlandKit/DesignSystem/DisplayFormatting.swift`
- Test: `MacIrlandTests/UIDisplayFormattingTests.swift`

- [ ] **Step 1: Write the failing tests**

Add these tests to `MacIrlandTests/UIDisplayFormattingTests.swift`:

```swift
func testTimelinePreviewEntriesDefaultToNewestThreeItems() {
    let session = makeSession(
        status: .waitingInput,
        historyEntries: [
            makeHistoryEntry(offset: 10, kind: .phaseRunning, title: "运行中"),
            makeHistoryEntry(offset: 20, kind: .phaseWaitingInput, title: "等待输入"),
            makeHistoryEntry(offset: 30, kind: .userQuickAction, title: "继续执行"),
            makeHistoryEntry(offset: 40, kind: .userCustomReply, title: "发送文本")
        ]
    )

    XCTAssertEqual(session.timelinePreviewEntries().map(\.title), ["发送文本", "继续执行", "等待输入"])
}

func testCompactSessionSubtitlePrefersActionableGuidanceForWaitingSession() {
    let session = makeSession(status: .waitingInput)
    XCTAssertEqual(session.compactSessionSubtitle, "等待你确认、补充信息或继续执行。")
}

func testDiagnosticsSummaryUsesBlockedExplanationWhenObservationFails() {
    let blocked = CapabilityStatus(
        accessibilityGranted: true,
        notificationsGranted: true,
        localOnlyProcessing: true,
        automationGranted: false,
        explanation: "未授权自动化",
        observationBlocked: true
    )

    XCTAssertEqual(blocked.panelDiagnosticsSummary, "终端读取失败，展开诊断查看权限或识别问题。")
    XCTAssertTrue(blocked.showsDiagnosticsExpandedByDefault)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter UIDisplayFormattingTests
```

Expected: FAIL with errors that `timelinePreviewEntries`, `compactSessionSubtitle`, `panelDiagnosticsSummary`, or `showsDiagnosticsExpandedByDefault` do not exist yet.

- [ ] **Step 3: Write minimal implementation**

Create `MacIrlandKit/Features/Panel/PanelPresentation.swift` with:

```swift
import Foundation

public extension TaskSession {
    var compactSessionSubtitle: String {
        if isAwaitingUser {
            return primaryGuidanceText
        }

        return summary
    }

    func timelinePreviewEntries(limit: Int = 3) -> [SessionHistoryEntry] {
        Array(timelineEntries.prefix(limit))
    }
}

public extension CapabilityStatus {
    var panelDiagnosticsSummary: String {
        if observationBlocked {
            return "终端读取失败，展开诊断查看权限或识别问题。"
        }

        return explanation
    }

    var showsDiagnosticsExpandedByDefault: Bool {
        observationBlocked
    }
}
```

Add the missing helper factory methods near the bottom of `MacIrlandTests/UIDisplayFormattingTests.swift`:

```swift
private func makeHistoryEntry(offset: TimeInterval, kind: SessionHistoryEntryKind, title: String) -> SessionHistoryEntry {
    SessionHistoryEntry(
        timestamp: Date(timeIntervalSince1970: offset),
        kind: kind,
        title: title,
        detail: title,
        relatedStatus: .waitingInput
    )
}
```

Update `makeSession` to accept custom history entries:

```swift
private func makeSession(
    status: TaskStatus = .running,
    terminalAppIdentifier: String = "com.apple.Terminal",
    historyEntries: [SessionHistoryEntry] = []
) -> TaskSession {
    TaskSession(
        identity: SessionIdentity(
            cliKind: .claudeCode,
            terminalAppIdentifier: terminalAppIdentifier,
            windowIdentifier: "Claude Code · ui",
            ttyIdentifier: "ttys001",
            startedAt: Date(timeIntervalSince1970: 0),
            lastSeenAt: Date(timeIntervalSince1970: 0)
        ),
        title: "UI refresh",
        status: status,
        priority: 1,
        confidence: 0.92,
        summary: "Refreshing the panel UI.",
        bridgeTarget: nil,
        replyCapability: ReplyCapability(
            status: .available,
            reason: "Ready",
            targetDescription: "Claude Code",
            channelStatus: "mock"
        ),
        lastActiveAt: Date(timeIntervalSince1970: 0),
        evidence: [],
        recentEvents: [],
        recentMessages: [],
        historyEntries: historyEntries,
        quickActions: [.continueExecution, .retry, .customText]
    )
}
```

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter UIDisplayFormattingTests
```

Expected: PASS, including the new panel-presentation helper tests.

- [ ] **Step 5: Commit**

```bash
git add \
  MacIrlandKit/Features/Panel/PanelPresentation.swift \
  MacIrlandTests/UIDisplayFormattingTests.swift
git commit -m "test: add panel simplification presentation helpers"
```

### Task 2: Refactor `PanelView` into an intervention-first layout

**Files:**
- Modify: `MacIrlandKit/Features/Panel/PanelView.swift`
- Modify: `MacIrlandKit/DesignSystem/PanelTheme.swift`
- Test: `MacIrlandTests/UIDisplayFormattingTests.swift`

- [ ] **Step 1: Write the failing tests**

Add these assertions to `MacIrlandTests/UIDisplayFormattingTests.swift`:

```swift
@MainActor
func testSessionDetailTimelineSubtitleDescribesPreviewInsteadOfFullHistory() {
    XCTAssertEqual(SessionDetailView.timelineSubtitle, "仅显示最近关键阶段，展开后再看完整历史。")
}

func testPanelDiagnosticsSummaryDefaultsToCapabilityExplanationWhenHealthy() {
    let healthy = CapabilityStatus(
        accessibilityGranted: true,
        notificationsGranted: true,
        localOnlyProcessing: true,
        automationGranted: true,
        explanation: "当前使用本地观察链路。",
        observationBlocked: false
    )

    XCTAssertEqual(healthy.panelDiagnosticsSummary, "当前使用本地观察链路。")
    XCTAssertFalse(healthy.showsDiagnosticsExpandedByDefault)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter UIDisplayFormattingTests
```

Expected: FAIL because the timeline subtitle and diagnostics-summary behavior have not been updated yet.

- [ ] **Step 3: Write minimal implementation**

Update `MacIrlandKit/Features/Panel/PanelView.swift` so the main stack becomes:

```swift
VStack(alignment: .leading, spacing: 16) {
    PanelHeaderView(
        summary: viewModel.summary,
        topSession: viewModel.topSession,
        capabilityStatus: viewModel.capabilityStatus,
        onRefresh: refresh
    )

    if let session = viewModel.selectedSession {
        PanelCard(tone: .elevated, padding: 20) {
            SessionDetailView(
                viewModel: viewModel,
                session: session,
                lastActionResult: $lastActionResult
            )
        }
    } else {
        PanelCard(tone: .elevated, padding: 20) {
            EmptyPrimaryWorkspaceView(message: sessionEmptyStateMessage)
        }
    }

    PanelCard {
        SessionPickerView(
            sessions: viewModel.sessions,
            selectedSessionID: viewModel.selectedSessionID,
            emptyStateMessage: sessionEmptyStateMessage,
            onSelect: handleSelection
        )
    }

    DiagnosticsDisclosureView(
        capabilityStatus: viewModel.capabilityStatus,
        observationDiagnostics: viewModel.observationDiagnostics,
        selectedSession: viewModel.selectedSession
    )
}
```

Replace the current heavy header with a compact one:

```swift
private struct PanelHeaderView: View {
    let summary: AppTaskSummary
    let topSession: TaskSession?
    let capabilityStatus: CapabilityStatus
    let onRefresh: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("macirland")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(topSession?.compactSessionSubtitle ?? "只保留需要你介入的任务和回复入口。")
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
            }
            .buttonStyle(.plain)
        }
    }
}
```

Add a disclosure-style diagnostics container in `PanelView.swift`:

```swift
private struct DiagnosticsDisclosureView: View {
    let capabilityStatus: CapabilityStatus
    let observationDiagnostics: ObservationDiagnostics
    let selectedSession: TaskSession?
    @State private var isExpanded: Bool

    init(capabilityStatus: CapabilityStatus, observationDiagnostics: ObservationDiagnostics, selectedSession: TaskSession?) {
        self.capabilityStatus = capabilityStatus
        self.observationDiagnostics = observationDiagnostics
        self.selectedSession = selectedSession
        _isExpanded = State(initialValue: capabilityStatus.showsDiagnosticsExpandedByDefault)
    }

    var body: some View {
        DisclosureGroup("诊断", isExpanded: $isExpanded) {
            DiagnosticsSectionView(
                session: selectedSession,
                capabilityStatus: capabilityStatus,
                observationDiagnostics: observationDiagnostics
            )
            .padding(.top, 10)
        } label: {
            Text(capabilityStatus.panelDiagnosticsSummary)
                .font(.footnote)
                .foregroundStyle(MacIrlandPalette.secondaryText)
        }
        .padding(14)
        .background(MacIrlandPalette.surface.opacity(0.55), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
```

Update `SessionDetailView.timelineSubtitle` to:

```swift
static let timelineSubtitle = "仅显示最近关键阶段，展开后再看完整历史。"
```

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter UIDisplayFormattingTests
swift build --package-path "/Users/lijunjie/Documents/AIproject/macirland"
```

Expected:
- `UIDisplayFormattingTests`: PASS
- `swift build`: PASS with the new compact panel layout

- [ ] **Step 5: Commit**

```bash
git add \
  MacIrlandKit/Features/Panel/PanelView.swift \
  MacIrlandKit/DesignSystem/PanelTheme.swift \
  MacIrlandTests/UIDisplayFormattingTests.swift
git commit -m "feat: simplify panel shell around intervention flow"
```

### Task 3: Compress session rows and foreground reply actions

**Files:**
- Modify: `MacIrlandKit/Features/Panel/SessionPickerView.swift`
- Modify: `MacIrlandKit/Features/Panel/SessionDetailView.swift`
- Test: `MacIrlandTests/UIDisplayFormattingTests.swift`

- [ ] **Step 1: Write the failing tests**

Add these tests to `MacIrlandTests/UIDisplayFormattingTests.swift`:

```swift
func testCompactSessionSubtitleFallsBackToSummaryForRunningSession() {
    let session = makeSession(status: .running)
    XCTAssertEqual(session.compactSessionSubtitle, "Refreshing the panel UI.")
}

func testTimelinePreviewEntriesKeepNewestItemFirst() {
    let session = makeSession(
        status: .waitingInput,
        historyEntries: [
            makeHistoryEntry(offset: 100, kind: .phaseRunning, title: "运行中"),
            makeHistoryEntry(offset: 300, kind: .phaseWaitingInput, title: "等待输入"),
            makeHistoryEntry(offset: 200, kind: .userQuickAction, title: "继续执行")
        ]
    )

    XCTAssertEqual(session.timelinePreviewEntries().first?.title, "等待输入")
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter UIDisplayFormattingTests
```

Expected: FAIL until the row/detail code is updated to use the new compact presentation helpers consistently.

- [ ] **Step 3: Write minimal implementation**

Update `MacIrlandKit/Features/Panel/SessionPickerView.swift` row layout to a compressed navigation row:

```swift
private struct SessionPickerRow: View {
    let session: TaskSession
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            StatusSpriteView(status: session.status)

            VStack(alignment: .leading, spacing: 4) {
                Text(session.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(session.compactSessionSubtitle)
                    .font(.caption)
                    .foregroundStyle(MacIrlandPalette.secondaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if session.isAwaitingUser {
                MetaChip("等待处理", systemImage: "hand.raised.fill", tint: .orange)
            } else {
                Text(session.relativeLastActiveText)
                    .font(.caption)
                    .foregroundStyle(MacIrlandPalette.tertiaryText)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(backgroundStyle, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
```

Update `MacIrlandKit/Features/Panel/SessionDetailView.swift` to move actions ahead of history and show only preview entries by default:

```swift
VStack(alignment: .leading, spacing: 18) {
    PanelSectionHeader("当前任务", subtitle: "优先处理等待你介入的步骤。")

    taskSummarySection

    detailSection("快捷回复") {
        FlowLayout(spacing: 8) {
            ForEach(session.quickActions, id: \.self) { action in
                Button(action.title) {
                    if action == .customText {
                        lastActionResult = viewModel.sendDraftReply(for: session)
                    } else {
                        viewModel.draftReply = action.defaultMessage
                        lastActionResult = viewModel.performQuickAction(action, for: session)
                    }
                }
                .buttonStyle(.bordered)
                .tint(IslandAccent.color(for: session.status))
            }
        }
    }

    detailSection("自由输入", subtitle: session.replyCapability.reason) {
        ...
    }

    if !session.timelineEntries.isEmpty {
        detailSection("最近关键阶段", subtitle: Self.timelineSubtitle) {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(session.timelinePreviewEntries()) { entry in
                    TimelineRow(
                        systemImage: entry.systemImage,
                        tint: entry.tint,
                        title: entry.title,
                        detail: entry.detail,
                        timeText: entry.timeText
                    )
                }
            }
        }
    }
}
```

Reduce metadata chips in `taskSummarySection` to:

```swift
HStack(spacing: 8) {
    MetaChip(session.status.label, systemImage: "waveform.path.ecg")
    MetaChip(session.relativeLastActiveText, systemImage: "clock")
    if session.isAwaitingUser {
        MetaChip("等待处理", systemImage: "hand.raised.fill", tint: .orange)
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter UIDisplayFormattingTests
swift build --package-path "/Users/lijunjie/Documents/AIproject/macirland"
```

Expected:
- `UIDisplayFormattingTests`: PASS
- `swift build`: PASS with compressed session rows and action-first detail layout

- [ ] **Step 5: Commit**

```bash
git add \
  MacIrlandKit/Features/Panel/SessionPickerView.swift \
  MacIrlandKit/Features/Panel/SessionDetailView.swift \
  MacIrlandTests/UIDisplayFormattingTests.swift
git commit -m "feat: prioritize reply actions in compact panel UI"
```

### Task 4: Verify the simplified panel end-to-end and update repo docs

**Files:**
- Modify: `CLAUDE.md`
- Test: `MacIrlandTests/UIDisplayFormattingTests.swift`

- [ ] **Step 1: Update project memory after implementation**

Add one short note under the current-progress/results sections in `CLAUDE.md`:

```md
- Panel 已按“介入处理优先”收敛：overview 和独立 hero 卡已移除，reply 区与主会话工作区前置，diagnostics 默认折叠。
```

- [ ] **Step 2: Run focused verification**

Run:

```bash
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland" --filter UIDisplayFormattingTests
swift test --package-path "/Users/lijunjie/Documents/AIproject/macirland"
swift build --package-path "/Users/lijunjie/Documents/AIproject/macirland"
```

Expected:
- `UIDisplayFormattingTests`: PASS
- full `swift test`: PASS
- `swift build`: PASS

- [ ] **Step 3: Manual UI verification**

Run:

```bash
cd /Users/lijunjie/Documents/AIproject/macirland
defaults write com.macirland.app OpenPanelOnLaunch -bool YES
./Scripts/run-dev-app.sh
```

Expected:
- Panel launches directly
- No overview card on first screen
- Quick actions and input are visible without large scrolling
- Diagnostics appear collapsed unless observation is blocked

- [ ] **Step 4: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: record intervention-first panel simplification"
```
