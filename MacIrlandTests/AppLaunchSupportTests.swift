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

    func testDevAppLauncherCodesignsWithStableBundleIdentifier() throws {
        let script = try String(contentsOfFile: "Scripts/run-dev-app.sh", encoding: .utf8)

        XCTAssertTrue(script.contains("codesign --force --deep --sign - --identifier \"$BUNDLE_ID\" \"$APP_DIR\""))
    }
}
