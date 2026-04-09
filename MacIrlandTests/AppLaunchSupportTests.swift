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

    func testPanelCoordinatorTogglePanelActivatesAppBeforeShowingPanel() throws {
        let source = try String(contentsOfFile: "MacIrlandApp/App/PanelCoordinator.swift", encoding: .utf8)

        let activateIndex = try XCTUnwrap(source.range(of: "NSApp.activate(ignoringOtherApps: true)")?.lowerBound)
        let frontIndex = try XCTUnwrap(source.range(of: "panel.makeKeyAndOrderFront(nil)")?.lowerBound)

        XCTAssertLessThan(activateIndex, frontIndex)
    }

    func testIslandCoordinatorObservesStoreSummaryAndTopSession() throws {
        let source = try String(contentsOfFile: "MacIrlandApp/App/IslandCoordinator.swift", encoding: .utf8)

        XCTAssertTrue(source.contains("withObservationTracking"))
        XCTAssertTrue(source.contains("_ = store.summary"))
        XCTAssertTrue(source.contains("_ = store.topSession"))
    }

    func testAppDelegateRoutesIslandTapToShowPanel() throws {
        let source = try String(contentsOfFile: "MacIrlandApp/App/AppDelegate.swift", encoding: .utf8)

        XCTAssertTrue(source.contains("showPanelSelectingSession(id:"))
    }

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

        XCTAssertTrue(source.contains("screenFrame.midX"))
        XCTAssertTrue(source.contains("screenFrame.maxY"))
        XCTAssertTrue(source.contains("setFrameOrigin"))
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
        let source = try String(contentsOfFile: "MacIrlandApp/App/IslandCoordinator.swift", encoding: .utf8)

        XCTAssertTrue(source.contains("dismissedHighlightedSessionID"))
    }

    func testIslandCoordinatorResizesWindowForHighlightedMode() throws {
        let source = try String(contentsOfFile: "MacIrlandApp/App/IslandCoordinator.swift", encoding: .utf8)

        XCTAssertTrue(source.contains("window.setContentSize"))
        XCTAssertTrue(source.contains("CGSize(width: 860, height: 152)"))
        XCTAssertTrue(source.contains("CGSize(width: 520, height: 44)"))
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
        let source = try String(contentsOfFile: "MacIrlandApp/App/IslandCoordinator.swift", encoding: .utf8)

        XCTAssertTrue(source.contains("store.performQuickAction"))
    }

    func testIslandSurfaceViewAnimatesModeChanges() throws {
        let source = try String(contentsOfFile: "MacIrlandKit/Features/Island/IslandSurfaceView.swift", encoding: .utf8)

        XCTAssertTrue(source.contains(".animation("))
        XCTAssertTrue(source.contains("value: mode"))
    }

    func testIslandExpandedCardUsesTransitionForHighlightedAppearance() throws {
        let source = try String(contentsOfFile: "MacIrlandKit/Features/Island/IslandExpandedCardView.swift", encoding: .utf8)

        XCTAssertTrue(source.contains(".transition("))
    }

    func testIslandExpandedCardDoesNotEmbedTextField() throws {
        let source = try String(contentsOfFile: "MacIrlandKit/Features/Island/IslandExpandedCardView.swift", encoding: .utf8)

        XCTAssertFalse(source.contains("TextField("))
    }

    func testIslandExpandedCardDoesNotRenderMultipleActionButtons() throws {
        let source = try String(contentsOfFile: "MacIrlandKit/Features/Island/IslandExpandedCardView.swift", encoding: .utf8)

        XCTAssertFalse(source.contains("ForEach("))
    }

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

    func testPanelCoordinatorExposesShowPanelFocusedOnTopSession() throws {
        let source = try String(contentsOfFile: "MacIrlandApp/App/PanelCoordinator.swift", encoding: .utf8)

        XCTAssertTrue(source.contains("func showPanelSelectingTopSession()"))
    }

    func testAppDelegateRoutesIslandOpenThroughFocusedPanelPath() throws {
        let source = try String(contentsOfFile: "MacIrlandApp/App/AppDelegate.swift", encoding: .utf8)

        XCTAssertTrue(source.contains("showPanelSelectingSession(id:"))
    }

    func testAppDelegateOwnsRefreshCoordinatorForAppWidePolling() throws {
        let source = try String(contentsOfFile: "MacIrlandApp/App/AppDelegate.swift", encoding: .utf8)

        XCTAssertTrue(source.contains("private lazy var refreshCoordinator"))
    }

    func testRefreshCoordinatorUsesOneSecondInterval() throws {
        let source = try String(contentsOfFile: "MacIrlandApp/App/RefreshCoordinator.swift", encoding: .utf8)

        XCTAssertTrue(source.contains("1.0"))
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
}
