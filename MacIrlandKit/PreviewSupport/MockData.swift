import Foundation

public enum MockData {
    public static var sampleEvents: [RawCLIEvent] {
        [
            RawCLIEvent(
                cliKind: .claudeCode,
                snippet: "Need user input: please confirm whether to proceed with the refactor.",
                snapshot: TerminalObservationSnapshot(
                    terminalAppIdentifier: "com.apple.Terminal",
                    windowTitle: "Claude Code · refactor flow",
                    commandLine: "claude code",
                    ttyIdentifier: "ttys001"
                )
            ),
            RawCLIEvent(
                cliKind: .codex,
                snippet: "Running tests for sidebar redesign…",
                snapshot: TerminalObservationSnapshot(
                    terminalAppIdentifier: "com.googlecode.iterm2",
                    windowTitle: "Codex · sidebar redesign",
                    commandLine: "codex --task sidebar",
                    ttyIdentifier: "ttys002"
                )
            ),
            RawCLIEvent(
                cliKind: .gemini,
                snippet: "Completed draft summary for release checklist.",
                snapshot: TerminalObservationSnapshot(
                    terminalAppIdentifier: "com.apple.Terminal",
                    windowTitle: "Gemini CLI · release",
                    commandLine: "gemini summarize",
                    ttyIdentifier: "ttys003"
                )
            )
        ]
    }
}
