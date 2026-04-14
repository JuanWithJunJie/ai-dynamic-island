import Foundation
import XCTest
@testable import MacIrlandKit

final class HookInstallerTests: XCTestCase {
    private var temporaryHome: URL!
    private var mockFileManager: FileManager!

    override func setUp() {
        super.setUp()
        // Create a temporary directory to simulate Claude home
        temporaryHome = FileManager.default.temporaryDirectory.appendingPathComponent("hook-test-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: temporaryHome, withIntermediateDirectories: true)

        // Create a mock file manager that uses our temp home
        mockFileManager = MockFileManager(homeDirectory: temporaryHome)
    }

    override func tearDown() {
        // Clean up temporary directory
        try? FileManager.default.removeItem(at: temporaryHome)
        super.tearDown()
    }

    /// Creates a HookInstaller configured to use temporary directories.
    private func makeInstaller() -> HookInstaller {
        let config = HookInstallerConfig(
            hooksDirectory: temporaryHome.appendingPathComponent(".claude/hooks"),
            settingsJSONPath: temporaryHome.appendingPathComponent(".claude/settings.json"),
            bundledScriptPath: URL(fileURLWithPath: "/Users/lijunjie/Documents/AIproject/macirland/MacIrlandKit/Scripts/macirland-hook.py")
        )
        return HookInstaller(config: config, fileManager: mockFileManager)
    }

    /// Returns the hooks directory in the simulated home
    private var hooksDirectory: URL {
        temporaryHome.appendingPathComponent(".claude/hooks")
    }

    /// Returns the hook script path in the simulated home
    private var hookScriptPath: URL {
        hooksDirectory.appendingPathComponent("macirland.py")
    }

    /// Returns the path to settings.json in the simulated home
    private var settingsJSONPath: URL {
        temporaryHome.appendingPathComponent(".claude/settings.json")
    }

    // MARK: - Test: Hook script installation

    func testInstallWritesHookScriptToHooksDirectory() throws {
        let installer = makeInstaller()

        // Verify hooks directory doesn't exist yet
        XCTAssertFalse(mockFileManager.fileExists(atPath: hooksDirectory.path))

        // Run install
        try installer.install()

        // Verify hook script was written
        XCTAssertTrue(mockFileManager.fileExists(atPath: hookScriptPath.path), "Hook script should be installed")

        // Verify script is executable (has 755 permissions)
        let attrs = try mockFileManager.attributesOfItem(atPath: hookScriptPath.path)
        let posixPermissions = attrs[.posixPermissions] as? Int
        XCTAssertEqual(posixPermissions, 0o755, "Hook script should be executable")
    }

    // MARK: - Test: settings.json hook registration

    func testInstallCreatesSettingsJSONWithHookEntries() throws {
        let installer = makeInstaller()

        // Verify settings.json doesn't exist yet
        XCTAssertFalse(mockFileManager.fileExists(atPath: settingsJSONPath.path))

        // Run install
        try installer.install()

        // settings.json should now exist
        XCTAssertTrue(mockFileManager.fileExists(atPath: settingsJSONPath.path), "settings.json should be created after install")
    }

    func testInstallSettingsJSONContainsRequiredHookEvents() throws {
        let installer = makeInstaller()
        try installer.install()

        let data = try Data(contentsOf: settingsJSONPath)
        let settings = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertNotNil(settings["hooks"], "settings.json should have 'hooks' key")

        let hooks = settings["hooks"] as! [String: Any]

        // Check required hook events from reference design
        let requiredEvents = [
            "UserPromptSubmit",
            "PostToolUse",
            "PermissionRequest",
            "Notification",
            "Stop",
            "SubagentStop",
            "SessionStart",
            "SessionEnd",
            "PreCompact"
        ]

        for event in requiredEvents {
            XCTAssertTrue(hooks.keys.contains(event), "Hook event '\(event)' should be registered")
        }
    }

    func testInstallSettingsJSONPreservesExistingUserHooks() throws {
        let installer = makeInstaller()

        // Pre-create settings.json with existing user hooks
        let existingSettings: [String: Any] = [
            "hooks": [
                "UserPromptSubmit": [[
                    "hooks": [[
                        "type": "command",
                        "command": "echo 'existing hook'"
                    ]],
                    "matcher": "custom-matcher"
                ]],
                "ExistingEvent": [[
                    "hooks": [[
                        "type": "command",
                        "command": "echo 'existing event'"
                    ]]
                ]]
            ],
            "someOtherSetting": "preserved"
        ]

        try mockFileManager.createDirectory(at: settingsJSONPath.deletingLastPathComponent(), withIntermediateDirectories: true)
        let existingData = try JSONSerialization.data(withJSONObject: existingSettings, options: [.prettyPrinted, .sortedKeys])
        try existingData.write(to: settingsJSONPath)

        // Run install
        try installer.install()

        // Existing settings should be preserved
        let data = try Data(contentsOf: settingsJSONPath)
        let settings = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertNotNil(settings["someOtherSetting"], "Existing user settings should be preserved")
        XCTAssertEqual(settings["someOtherSetting"] as? String, "preserved")

        let hooks = settings["hooks"] as! [String: Any]
        XCTAssertTrue(hooks.keys.contains("ExistingEvent"), "Existing hook events should be preserved")

        // User's custom UserPromptSubmit should be preserved (merged, not clobbered)
        let userPromptSubmit = hooks["UserPromptSubmit"] as? [[String: Any]]
        XCTAssertEqual(userPromptSubmit?.count, 2, "Should have both user and MacIrland UserPromptSubmit entries")
    }

    func testInstallSettingsJSONUsesCorrectHookCommand() throws {
        let installer = makeInstaller()
        try installer.install()

        let data = try Data(contentsOf: settingsJSONPath)
        let settings = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let hooks = settings["hooks"] as! [String: Any]

        // Get any hook command and verify it references macirland.py
        let userPromptSubmit = hooks["UserPromptSubmit"] as? [[String: Any]]
        let hookEntry = userPromptSubmit?.first?["hooks"] as? [[String: Any]]
        let command = hookEntry?.first?["command"] as? String

        XCTAssertNotNil(command, "Hook command should be present")
        XCTAssertTrue(command!.contains("macirland.py"), "Hook command should reference macirland.py")
        XCTAssertTrue(command!.contains("python3"), "Hook command should use python3")
    }

    // MARK: - Test: Hook entries have correct structure per reference design

    func testInstallSettingsJSONPostToolUseHasMatcher() throws {
        let installer = makeInstaller()
        try installer.install()

        // PostToolUse should have matcher: "*" per reference design
        let data = try Data(contentsOf: settingsJSONPath)
        let settings = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let hooks = settings["hooks"] as! [String: Any]

        let postToolUse = hooks["PostToolUse"] as? [[String: Any]]
        XCTAssertNotNil(postToolUse)
        XCTAssertEqual(postToolUse?.first?["matcher"] as? String, "*", "PostToolUse should have matcher: '*'")
    }

    func testInstallSettingsJSONPreCompactHasBothMatchers() throws {
        let installer = makeInstaller()
        try installer.install()

        // PreCompact should have both "auto" and "manual" matchers per reference design
        let data = try Data(contentsOf: settingsJSONPath)
        let settings = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let hooks = settings["hooks"] as! [String: Any]

        let preCompact = hooks["PreCompact"] as? [[String: Any]]
        XCTAssertNotNil(preCompact)
        XCTAssertEqual(preCompact?.count, 2, "PreCompact should have 2 entries (auto and manual)")

        let matchers = preCompact?.compactMap { entry -> String? in
            guard let dict = entry as? [String: Any] else { return nil }
            return dict["matcher"] as? String
        }
        XCTAssertTrue(matchers?.contains("auto") ?? false, "PreCompact should have 'auto' matcher")
        XCTAssertTrue(matchers?.contains("manual") ?? false, "PreCompact should have 'manual' matcher")
    }

    func testInstallSettingsJSONPermissionRequestHasTimeout() throws {
        let installer = makeInstaller()
        try installer.install()

        // PermissionRequest should have timeout: 86400 per reference design
        let data = try Data(contentsOf: settingsJSONPath)
        let settings = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let hooks = settings["hooks"] as! [String: Any]

        let permissionRequest = hooks["PermissionRequest"] as? [[String: Any]]
        XCTAssertNotNil(permissionRequest)
        let hookEntry = permissionRequest?.first?["hooks"] as? [[String: Any]]
        let timeout = hookEntry?.first?["timeout"] as? Int
        XCTAssertEqual(timeout, 86400, "PermissionRequest hook should have timeout: 86400")
    }

    func testInstallSettingsJSONNotificationHasTimeout() throws {
        let installer = makeInstaller()
        try installer.install()

        // Notification should have timeout: 86400 per reference design
        let data = try Data(contentsOf: settingsJSONPath)
        let settings = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let hooks = settings["hooks"] as! [String: Any]

        let notification = hooks["Notification"] as? [[String: Any]]
        XCTAssertNotNil(notification)
        let hookEntry = notification?.first?["hooks"] as? [[String: Any]]
        let timeout = hookEntry?.first?["timeout"] as? Int
        XCTAssertEqual(timeout, 86400, "Notification hook should have timeout: 86400")
    }

    func testInstallSettingsJSONSimpleEventsHaveNoTimeout() throws {
        let installer = makeInstaller()
        try installer.install()

        // Simple events (without matcher) should not have timeout
        let data = try Data(contentsOf: settingsJSONPath)
        let settings = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let hooks = settings["hooks"] as! [String: Any]

        let simpleEvents = ["UserPromptSubmit", "Stop", "SubagentStop", "SessionStart", "SessionEnd"]
        for event in simpleEvents {
            let entries = hooks[event] as? [[String: Any]]
            XCTAssertNotNil(entries)
            let hookEntry = entries?.first?["hooks"] as? [[String: Any]]
            XCTAssertNil(hookEntry?.first?["timeout"], "\(event) should not have timeout")
        }
    }

    // MARK: - Test: checkInstalled and uninstall

    func testCheckInstalledReturnsFalseWhenNotInstalled() throws {
        let installer = makeInstaller()
        XCTAssertFalse(mockFileManager.fileExists(atPath: hookScriptPath.path))
        XCTAssertFalse(installer.checkInstalled())
    }

    func testIsFullyInstalledReturnsFalseWhenOnlyScriptExists() throws {
        let installer = makeInstaller()

        try mockFileManager.createDirectory(at: hooksDirectory, withIntermediateDirectories: true)
        try "#!/usr/bin/env python3".write(to: hookScriptPath, atomically: true, encoding: .utf8)

        XCTAssertTrue(installer.checkInstalled())
        XCTAssertFalse(installer.isFullyInstalled())
    }

    func testIsFullyInstalledReturnsTrueAfterInstall() throws {
        let installer = makeInstaller()

        try installer.install()

        XCTAssertTrue(installer.checkInstalled())
        XCTAssertTrue(installer.isFullyInstalled())
    }

    func testUninstallRemovesHookScript() throws {
        let installer = makeInstaller()
        try installer.install()

        XCTAssertTrue(mockFileManager.fileExists(atPath: hookScriptPath.path))

        try installer.uninstall()

        XCTAssertFalse(mockFileManager.fileExists(atPath: hookScriptPath.path), "Hook script should be removed after uninstall")
    }

    func testUninstallDoesNotRemoveSettingsJSON() throws {
        let installer = makeInstaller()
        try installer.install()

        XCTAssertTrue(mockFileManager.fileExists(atPath: settingsJSONPath.path))

        try installer.uninstall()

        // settings.json should still exist (uninstall only removes the hook script)
        XCTAssertTrue(mockFileManager.fileExists(atPath: settingsJSONPath.path), "settings.json should not be removed by uninstall")
    }
}

// MARK: - Mock FileManager for Testing

/// A mock FileManager that uses a custom home directory for path resolution.
private final class MockFileManager: FileManager {
    private let customHomeDirectory: URL

    init(homeDirectory: URL) {
        self.customHomeDirectory = homeDirectory
        super.init()
    }

    override var homeDirectoryForCurrentUser: URL {
        customHomeDirectory
    }
}
