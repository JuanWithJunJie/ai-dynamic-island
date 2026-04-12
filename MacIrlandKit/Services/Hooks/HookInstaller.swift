import Foundation

/// Configuration for HookInstaller paths.
/// Used to allow testing with isolated directories.
public struct HookInstallerConfig: Sendable {
    public var hooksDirectory: URL
    public var settingsJSONPath: URL
    public var bundledScriptPath: URL

    public init(
        hooksDirectory: URL,
        settingsJSONPath: URL,
        bundledScriptPath: URL
    ) {
        self.hooksDirectory = hooksDirectory
        self.settingsJSONPath = settingsJSONPath
        self.bundledScriptPath = bundledScriptPath
    }

    public static var `default`: HookInstallerConfig {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let sourceRoot = URL(fileURLWithPath: #file)
            .deletingLastPathComponent() // HookInstaller
            .deletingLastPathComponent() // Hooks
            .deletingLastPathComponent() // Services
        return HookInstallerConfig(
            hooksDirectory: home.appendingPathComponent(".claude/hooks"),
            settingsJSONPath: home.appendingPathComponent(".claude/settings.json"),
            bundledScriptPath: sourceRoot
                .appendingPathComponent("Scripts")
                .appendingPathComponent("macirland-hook.py")
        )
    }

    public static var hookScriptName: String { "macirland.py" }

    public var hookScriptPath: URL {
        hooksDirectory.appendingPathComponent(Self.hookScriptName)
    }

    public var hookCommand: String {
        "python3 \(hookScriptPath.path)"
    }
}

/// Installs, detects, and uninstalls the Claude Code Python hook.
public final class HookInstaller {
    private let config: HookInstallerConfig
    private let fileManager: FileManager

    /// Creates a HookInstaller with the default configuration.
    public init() {
        self.config = .default
        self.fileManager = .default
    }

    /// Creates a HookInstaller with a custom configuration (for testing).
    internal init(config: HookInstallerConfig, fileManager: FileManager = .default) {
        self.config = config
        self.fileManager = fileManager
    }

    /// Checks whether the MacIrland hook is currently installed.
    public func checkInstalled() -> Bool {
        fileManager.fileExists(atPath: config.hookScriptPath.path)
    }

    /// Installs the hook script to ~/.claude/hooks/macirland.py
    /// and sets appropriate permissions.
    public func install() throws {
        // Create hooks directory if it doesn't exist
        try fileManager.createDirectory(at: config.hooksDirectory, withIntermediateDirectories: true)

        // Read bundled script
        let script = try String(contentsOf: config.bundledScriptPath, encoding: .utf8)

        try script.write(to: config.hookScriptPath, atomically: true, encoding: .utf8)

        // Make it executable
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: config.hookScriptPath.path)

        // Register hooks in settings.json
        try registerHooksInSettings()
    }

    /// Registers MacIrland hooks in ~/.claude/settings.json.
    /// Creates settings.json if absent and merges hook entries without clobbering existing user configuration.
    private func registerHooksInSettings() throws {
        var settings: [String: Any]

        // Load existing settings or start fresh
        if fileManager.fileExists(atPath: config.settingsJSONPath.path) {
            let data = try Data(contentsOf: config.settingsJSONPath)
            settings = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        } else {
            settings = [:]
        }

        // Ensure hooks section exists
        var hooks = settings["hooks"] as? [String: Any] ?? [:]

        // Merge MacIrland hook entries
        let macIrlandHooks = buildMacIrlandHookEntries()
        for (event, entries) in macIrlandHooks {
            // For UserPromptSubmit, SessionStart, SessionEnd, Stop, SubagentStop:
            // append MacIrland entry alongside existing ones (don't clobber)
            // For events with matchers (PostToolUse, PermissionRequest, Notification, PreCompact):
            // we own those entirely in our design, but we check for conflict
            if hooks[event] != nil {
                // If user has custom entries, append our entry
                var existing = hooks[event] as? [[String: Any]] ?? []
                existing.append(contentsOf: entries)
                hooks[event] = existing
            } else {
                hooks[event] = entries
            }
        }

        settings["hooks"] = hooks

        // Ensure .claude directory exists
        try fileManager.createDirectory(
            at: config.settingsJSONPath.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        // Write settings.json with sorted keys for readability
        let data = try JSONSerialization.data(
            withJSONObject: settings,
            options: [.prettyPrinted, .sortedKeys]
        )
        try data.write(to: config.settingsJSONPath)
    }

    /// Builds the MacIrland hook entries for all events.
    /// Matches the reference design format.
    private func buildMacIrlandHookEntries() -> [String: [[String: Any]]] {
        let command = config.hookCommand

        return [
            "UserPromptSubmit": [[
                "hooks": [[
                    "type": "command",
                    "command": command
                ]]
            ]],
            "PostToolUse": [[
                "matcher": "*",
                "hooks": [[
                    "type": "command",
                    "command": command,
                    "timeout": 86400
                ]]
            ]],
            "PermissionRequest": [[
                "matcher": "*",
                "hooks": [[
                    "type": "command",
                    "command": command,
                    "timeout": 86400
                ]]
            ]],
            "Notification": [[
                "matcher": "*",
                "hooks": [[
                    "type": "command",
                    "command": command,
                    "timeout": 86400
                ]]
            ]],
            "Stop": [[
                "hooks": [[
                    "type": "command",
                    "command": command
                ]]
            ]],
            "SubagentStop": [[
                "hooks": [[
                    "type": "command",
                    "command": command
                ]]
            ]],
            "SessionStart": [[
                "hooks": [[
                    "type": "command",
                    "command": command
                ]]
            ]],
            "SessionEnd": [[
                "hooks": [[
                    "type": "command",
                    "command": command
                ]]
            ]],
            "PreCompact": [
                [
                    "matcher": "auto",
                    "hooks": [[
                        "type": "command",
                        "command": command
                    ]]
                ],
                [
                    "matcher": "manual",
                    "hooks": [[
                        "type": "command",
                        "command": command
                    ]]
                ]
            ]
        ]
    }

    /// Uninstalls the hook script.
    public func uninstall() throws {
        if fileManager.fileExists(atPath: config.hookScriptPath.path) {
            try fileManager.removeItem(at: config.hookScriptPath)
        }
    }
}
