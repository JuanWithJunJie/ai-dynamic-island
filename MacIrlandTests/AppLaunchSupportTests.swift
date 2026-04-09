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
}
