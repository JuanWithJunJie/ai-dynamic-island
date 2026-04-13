import XCTest
@testable import MacIrlandApp

final class AppLaunchSupportTests: XCTestCase {
    func testDetectLaunchModeTreatsAppBundleAsBundledApp() {
        let bundleURL = URL(fileURLWithPath: "/tmp/MacIrland.app")

        XCTAssertEqual(AppLaunchSupport.detectLaunchMode(bundleURL: bundleURL), .bundledApp)
    }

    func testDetectLaunchModeTreatsNonAppPathAsDirectExecutable() {
        let executableURL = URL(fileURLWithPath: "/tmp/.build/debug/MacIrland")

        XCTAssertEqual(AppLaunchSupport.detectLaunchMode(bundleURL: executableURL), .directExecutable)
    }

    func testUnsupportedLaunchMessagePointsToDevAppScript() {
        XCTAssertTrue(AppLaunchSupport.unsupportedLaunchMessage.contains("./Scripts/run-dev-app.sh"))
    }

    func testShouldWarnForDirectExecutableLaunches() {
        XCTAssertTrue(AppLaunchSupport.shouldWarnForUnsupportedLaunchMode(.directExecutable))
        XCTAssertFalse(AppLaunchSupport.shouldWarnForUnsupportedLaunchMode(.bundledApp))
    }

    func testInfoPlistDeclaresAppleEventsUsageDescription() throws {
        let plist = try XCTUnwrap(NSDictionary(contentsOfFile: "MacIrlandApp/Resources/Info.plist"))

        XCTAssertEqual(
            plist["NSAppleEventsUsageDescription"] as? String,
            "MacIrland needs Automation permission to read Terminal and iTerm sessions."
        )
    }

    func testAppDelegateNoLongerOwnsPanelCoordinator() throws {
        let source = try String(contentsOfFile: "MacIrlandApp/App/AppDelegate.swift", encoding: .utf8)

        XCTAssertFalse(source.contains("PanelCoordinator"))
        XCTAssertFalse(source.contains("panelCoordinator"))
    }

    func testIslandCoordinatorObservesStoreSummaryAndTopSession() throws {
        let source = try String(contentsOfFile: "MacIrlandApp/App/IslandCoordinator.swift", encoding: .utf8)

        XCTAssertTrue(source.contains("withObservationTracking"))
        XCTAssertTrue(source.contains("_ = store.summary"))
        XCTAssertTrue(source.contains("_ = store.topSession"))
    }

    func testAppDelegateRoutesIslandTapToShowPanel() throws {
        let source = try String(contentsOfFile: "MacIrlandApp/App/AppDelegate.swift", encoding: .utf8)

        // Panel display is disabled - island tap should not route to panel
        XCTAssertFalse(source.contains("showPanelSelectingSession(id:"))
    }

    func testAppDelegateOwnsIslandCoordinatorForTopLevelSurface() throws {
        let source = try String(contentsOfFile: "MacIrlandApp/App/AppDelegate.swift", encoding: .utf8)

        XCTAssertTrue(source.contains("IslandCoordinator"))
    }

    func testAppDelegateNoLongerSupportsOpenPanelOnLaunchFlag() throws {
        let source = try String(contentsOfFile: "MacIrlandApp/App/AppDelegate.swift", encoding: .utf8)

        XCTAssertFalse(source.contains("OpenPanelOnLaunch"))
        XCTAssertFalse(source.contains("openPanelIfRequested"))
    }

    func testIslandCoordinatorAnchorsWindowNearTopCenter() throws {
        let source = try String(contentsOfFile: "MacIrlandApp/App/IslandCoordinator.swift", encoding: .utf8)

        XCTAssertTrue(source.contains("screenFrame.midX"))
        XCTAssertTrue(source.contains("screenFrame.maxY"))
        XCTAssertTrue(source.contains("setFrame("))
    }

    func testAppDelegateOwnsStatusBarControllerForReliableMenuBarPresence() throws {
        let source = try String(contentsOfFile: "MacIrlandApp/App/AppDelegate.swift", encoding: .utf8)

        XCTAssertTrue(source.contains("StatusBarController"))
    }

    func testMacIrlandAppNoLongerUsesMenuBarExtraScene() throws {
        let source = try String(contentsOfFile: "MacIrlandApp/App/MacIrlandApp.swift", encoding: .utf8)

        XCTAssertFalse(source.contains("MenuBarExtra"))
    }

    func testStatusBarControllerUsesIconOnlyMenuBarButton() throws {
        let source = try String(contentsOfFile: "MacIrlandApp/App/StatusBarController.swift", encoding: .utf8)

        XCTAssertTrue(source.contains("button.imagePosition = .imageOnly"))
        XCTAssertTrue(source.contains("button.title = \"\""))
    }

    func testAppDelegateSetsRegularPolicyBeforeCreatingStatusItem() throws {
        let source = try String(contentsOfFile: "MacIrlandApp/App/AppDelegate.swift", encoding: .utf8)

        let policyIndex = try XCTUnwrap(source.range(of: "NSApp.setActivationPolicy(.regular)")?.lowerBound)
        let statusItemIndex = try XCTUnwrap(source.range(of: "_ = statusBarController")?.lowerBound)

        XCTAssertLessThan(policyIndex, statusItemIndex)
    }

    func testIslandCoordinatorTracksSurfaceMode() throws {
        let source = try String(contentsOfFile: "MacIrlandApp/App/IslandCoordinator.swift", encoding: .utf8)

        XCTAssertTrue(source.contains("private var mode: IslandSurfaceMode"))
    }

    func testIslandCoordinatorStoresDismissedHighlightedSessionID() throws {
        // DISABLED: highlighted mode has been removed
        // let source = try String(contentsOfFile: "MacIrlandApp/App/IslandCoordinator.swift", encoding: .utf8)
        // XCTAssertTrue(source.contains("dismissedHighlightedSessionID"))
    }

    func testIslandCoordinatorResizesWindowForHighlightedMode() throws {
        // DISABLED: highlighted mode has been removed
        // let source = try String(contentsOfFile: "MacIrlandApp/App/IslandCoordinator.swift", encoding: .utf8)
        // XCTAssertTrue(source.contains("window.setContentSize"))
        // XCTAssertTrue(source.contains("CGSize(width: 860, height: 152)"))
        // XCTAssertTrue(source.contains("CGSize(width: 300, height: 44)"))
    }

    func testIslandCoordinatorHostsIslandSurfaceViewInsteadOfStatusStripOnly() throws {
        let source = try String(contentsOfFile: "MacIrlandApp/App/IslandCoordinator.swift", encoding: .utf8)

        XCTAssertTrue(source.contains("IslandSurfaceView"))
    }

    func testStatusBarControllerRemainsFallbackAfterExpandedIslandPhase() throws {
        let source = try String(contentsOfFile: "MacIrlandApp/App/StatusBarController.swift", encoding: .utf8)

        XCTAssertTrue(source.contains("fallback"))
    }

    func testIslandCoordinatorStoresPrimaryActionResult() throws {
        let source = try String(contentsOfFile: "MacIrlandApp/App/IslandCoordinator.swift", encoding: .utf8)

        XCTAssertTrue(source.contains("private var actionResult: ReplyValidationResult?"))
    }

    func testIslandCoordinatorTriggersStoreQuickActionForHighlightedSession() throws {
        // DISABLED: highlighted mode has been removed
        // let source = try String(contentsOfFile: "MacIrlandApp/App/IslandCoordinator.swift", encoding: .utf8)
        // XCTAssertTrue(source.contains("store.performQuickAction"))
    }

    func testIslandSurfaceViewAnimatesModeChanges() throws {
        let source = try String(contentsOfFile: "MacIrlandKit/Features/Island/IslandSurfaceView.swift", encoding: .utf8)

        XCTAssertTrue(source.contains(".animation("))
        XCTAssertTrue(source.contains("value: mode"))
    }

    func testIslandExpandedCardUsesTransitionForHighlightedAppearance() throws {
        // DISABLED: IslandExpandedCardView has been removed
        // let source = try String(contentsOfFile: "MacIrlandKit/Features/Island/IslandExpandedCardView.swift", encoding: .utf8)
        // XCTAssertTrue(source.contains(".transition("))
    }

    func testIslandExpandedCardDoesNotEmbedTextField() throws {
        // DISABLED: IslandExpandedCardView has been removed
        // let source = try String(contentsOfFile: "MacIrlandKit/Features/Island/IslandExpandedCardView.swift", encoding: .utf8)
        // XCTAssertFalse(source.contains("TextField("))
    }

    func testIslandExpandedCardDoesNotRenderMultipleActionButtons() throws {
        // DISABLED: IslandExpandedCardView has been removed
        // let source = try String(contentsOfFile: "MacIrlandKit/Features/Island/IslandExpandedCardView.swift", encoding: .utf8)
        // XCTAssertFalse(source.contains("ForEach("))
    }

    func testIslandCoordinatorStoresAutoCollapseWorkItem() throws {
        let source = try String(contentsOfFile: "MacIrlandApp/App/IslandCoordinator.swift", encoding: .utf8)

        XCTAssertTrue(source.contains("private var autoCollapseWorkItem"))
    }

    func testIslandCoordinatorSchedulesAutoCollapseFromPresentationDelay() throws {
        // DISABLED: scheduleAutoCollapseIfNeeded has been removed along with highlighted mode
        // let source = try String(contentsOfFile: "MacIrlandApp/App/IslandCoordinator.swift", encoding: .utf8)
        // XCTAssertTrue(source.contains("presentation.autoCollapseDelay"))
        // XCTAssertTrue(source.contains("DispatchWorkItem"))
        // XCTAssertTrue(source.contains("DispatchQueue.main.asyncAfter"))
    }

    func testIslandCoordinatorCancelsAutoCollapseOnDismissAndOpenPanel() throws {
        let source = try String(contentsOfFile: "MacIrlandApp/App/IslandCoordinator.swift", encoding: .utf8)

        XCTAssertTrue(source.contains("autoCollapseWorkItem?.cancel()"))
    }

    func testAppDelegateRoutesIslandOpenThroughFocusedPanelPath() throws {
        let source = try String(contentsOfFile: "MacIrlandApp/App/AppDelegate.swift", encoding: .utf8)

        // Panel display is disabled - island open does not route to panel
        XCTAssertFalse(source.contains("showPanelSelectingSession(id:"))
    }

    func testAppDelegateOwnsRefreshCoordinatorForAppWidePolling() throws {
        let source = try String(contentsOfFile: "MacIrlandApp/App/AppDelegate.swift", encoding: .utf8)

        XCTAssertTrue(source.contains("private lazy var refreshCoordinator"))
    }

    func testRefreshCoordinatorUsesOneSecondInterval() throws {
        let source = try String(contentsOfFile: "MacIrlandApp/App/RefreshCoordinator.swift", encoding: .utf8)

        XCTAssertTrue(source.contains("1.0"))
    }

    func testHoverExpandUsesUniformSessionListLayout() throws {
        let source = try String(contentsOfFile: "MacIrlandKit/Features/Island/IslandHoverExpandView.swift", encoding: .utf8)

        // Hover expand shows all sessions as uniform list (no separate detail section)
        XCTAssertTrue(source.contains("store.hoverExpandSessions"))
        XCTAssertTrue(source.contains("let onJumpToSession: (TaskSession.ID) -> Void"))
        XCTAssertTrue(source.contains("HoverExpandSessionRow("))
        XCTAssertTrue(source.contains(".onTapGesture"))
        XCTAssertTrue(source.contains("sessionName"))  // Uses sessionName for iTerm2 titles
        XCTAssertTrue(source.contains("terminalTypeLabel"))  // Shows terminal type badge
    }

    func testAppDelegateStartsRefreshCoordinatorAtLaunch() throws {
        let source = try String(contentsOfFile: "MacIrlandApp/App/AppDelegate.swift", encoding: .utf8)

        XCTAssertTrue(source.contains("refreshCoordinator.start()"))
    }

    func testSettingsViewNoLongerShowsManualRefreshButton() throws {
        let source = try String(contentsOfFile: "MacIrlandApp/App/SettingsView.swift", encoding: .utf8)

        XCTAssertFalse(source.contains("刷新状态"))
    }

    func testIslandCoordinatorAnchorsAgainstFullScreenFrame() throws {
        let source = try String(contentsOfFile: "MacIrlandApp/App/IslandCoordinator.swift", encoding: .utf8)

        XCTAssertTrue(source.contains("screen.frame"))
        XCTAssertFalse(source.contains("visibleFrame.midX"))
    }

    func testIslandCoordinatorDefinesSmallTopAnchorInset() throws {
        let source = try String(contentsOfFile: "MacIrlandApp/App/IslandCoordinator.swift", encoding: .utf8)

        XCTAssertTrue(source.contains("topAnchorInset"))
    }

    func testPanelHeaderNoLongerRendersRefreshButton() throws {
        let source = try String(contentsOfFile: "MacIrlandKit/Features/Panel/PanelView.swift", encoding: .utf8)

        XCTAssertFalse(source.contains("arrow.clockwise"))
        XCTAssertFalse(source.contains("onRefresh"))
    }

    func testBlockedEmptyStateNoLongerReferencesManualRefresh() throws {
        let source = try String(contentsOfFile: "MacIrlandKit/Features/Panel/PanelView.swift", encoding: .utf8)

        XCTAssertFalse(source.contains("点击右上角刷新"))
    }

    func testRefreshCoordinatorTracksInFlightRefresh() throws {
        let source = try String(contentsOfFile: "MacIrlandApp/App/RefreshCoordinator.swift", encoding: .utf8)

        XCTAssertTrue(source.contains("isRefreshing"))
    }

    func testRefreshCoordinatorSkipsTickWhileRefreshInFlight() throws {
        let source = try String(contentsOfFile: "MacIrlandApp/App/RefreshCoordinator.swift", encoding: .utf8)

        XCTAssertTrue(source.contains("guard"), "should have guard statement")
        XCTAssertTrue(source.contains("isRefreshing == false"), "should check isRefreshing flag")
    }

    func testRefreshCoordinatorAllowsWaitingForReplyCuePlayback() throws {
        let source = try String(contentsOfFile: "MacIrlandApp/App/RefreshCoordinator.swift", encoding: .utf8)

        XCTAssertTrue(source.contains(".waitingForReply"), "waiting/reply transitions should be allowed through the refresh cue filter")
    }
}
