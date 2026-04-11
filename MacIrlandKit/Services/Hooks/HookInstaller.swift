import Foundation

/// Installs, detects, and uninstalls the Claude Code Python hook.
public final class HookInstaller: Sendable {
    public static let hookFileName = "macirland.py"

    /// Path to the hooks directory in Claude Code config.
    public static var hooksDirectory: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".claude/hooks")
    }

    /// Full path to the installed hook script.
    public static var hookScriptPath: URL {
        hooksDirectory.appendingPathComponent(hookFileName)
    }

    /// Path to the bundled hook script source file.
    private static var bundledScriptPath: URL {
        let sourceRoot = URL(fileURLWithPath: #file)
            .deletingLastPathComponent() // HookInstaller
            .deletingLastPathComponent() // Hooks
            .deletingLastPathComponent() // Services
            .appendingPathComponent("Scripts")
            .appendingPathComponent("macirland-hook.py")
        return sourceRoot
    }

    public init() {}

    /// Checks whether the MacIrland hook is currently installed.
    public func checkInstalled() -> Bool {
        FileManager.default.fileExists(atPath: Self.hookScriptPath.path)
    }

    /// Installs the hook script to ~/.claude/hooks/macirland.py
    /// and sets appropriate permissions.
    public func install() throws {
        let hooksDir = Self.hooksDirectory
        let hookPath = Self.hookScriptPath

        // Create hooks directory if it doesn't exist
        try FileManager.default.createDirectory(at: hooksDir, withIntermediateDirectories: true)

        // Read bundled script from MacIrlandKit/Scripts/
        let script = try String(contentsOf: Self.bundledScriptPath, encoding: .utf8)

        try script.write(to: hookPath, atomically: true, encoding: .utf8)

        // Make it executable
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: hookPath.path)
    }

    /// Uninstalls the hook script.
    public func uninstall() throws {
        if FileManager.default.fileExists(atPath: Self.hookScriptPath.path) {
            try FileManager.default.removeItem(at: Self.hookScriptPath)
        }
    }
}
