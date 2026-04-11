import Foundation
import AppKit

/// Service for jumping to Terminal/iTerm tabs via AppleScript
public enum TerminalJumpService {
    /// Jump to and activate the Terminal/iTerm tab for the given session
    public static func jump(to session: TaskSession) {
        let script: String
        let appIdentifier = session.identity.terminalAppIdentifier
        switch appIdentifier {
        case "com.apple.Terminal":
            script = terminalJumpScript(session: session)
        case "com.googlecode.iterm2":
            script = iTermJumpScript(session: session)
        default:
            print("TerminalJumpService: Unknown terminal app identifier '\(appIdentifier)' - cannot jump. tty=\(session.identity.ttyIdentifier ?? "nil"), window=\(session.identity.windowIdentifier)")
            return
        }

        NSLog("TerminalJumpService: Jumping. tty=%@ window=%@ cmdLine=%@", session.identity.ttyIdentifier ?? "nil", session.identity.windowIdentifier, session.identity.commandLine)
        let result = AppleScriptRunner.run(script: script)
        if let error = result.errorDescription {
            NSLog("TerminalJumpService: AppleScript failed - %@", error)
        } else {
            NSLog("TerminalJumpService: Jump completed")
        }
    }

    private static func terminalJumpScript(session: TaskSession) -> String {
        let tty = session.identity.ttyIdentifier
        let windowTitle = session.identity.windowIdentifier.appleScriptEscaped
        let commandLine = session.identity.commandLine.appleScriptEscaped

        // Matching priority:
        // 1. tty (most reliable — unique per terminal tab)
        // 2. commandLine in tabProcess (unique per Claude invocation)
        // 3. windowTitle only (weak — use last when nothing else is available)

        var conditions: [String] = []

        // Priority 1: tty — unique per terminal tab, most reliable
        if let tty, !tty.isEmpty {
            conditions.append("tty of eachTab is \"\(tty)\"")
        }

        // Priority 2: commandLine in tabProcess — process list contains the invocation
        if !commandLine.isEmpty {
            conditions.append("tabProcess contains \"\(commandLine)\"")
        }

        // Priority 3: windowName contains windowIdentifier — use substring match
        // windowIdentifier includes TERM_SESSION_ID which is unique per tab.
        // Reverse check: windowIdentifier is contained within windowName.
        if !windowTitle.isEmpty {
            conditions.append("(\"\(windowTitle)\" is in windowName)")
        }

        let matchConditions = conditions.joined(separator: " or ")

        print("""
        TerminalJumpService: RAW APPLE SCRIPT CONDITIONS
          tty: \(tty ?? "nil")
          windowIdentifier (windowTitle): '\(session.identity.windowIdentifier)'
          commandLine: '\(session.identity.commandLine)'
          conditions: \(conditions)
          final matchConditions: '\(matchConditions)'
        """)

        return """
        tell application "Terminal"
            set targetTab to null
            repeat with eachWindow in windows
                set windowName to ""
                try
                    set windowName to name of eachWindow
                end try

                repeat with eachTab in tabs of eachWindow
                    set tabName to ""
                    try
                        set tabName to custom title of eachTab
                    end try
                    if tabName is "" then
                        try
                            set tabName to name of eachTab
                        end try
                    end if

                    set tabProcess to ""
                    try
                        set tabProcess to processes of eachTab as text
                    end try

                    if (\(matchConditions)) then
                        set targetTab to eachTab
                        exit repeat
                    end if
                end repeat

                if targetTab is not null then
                    exit repeat
                end if
            end repeat

            if targetTab is not null then
                activate
                set selected of targetTab to true
                set frontmost of first window to true
            end if
        end tell
        """
    }

    private static func iTermJumpScript(session: TaskSession) -> String {
        let ttyId = session.identity.ttyIdentifier?.appleScriptEscaped ?? ""
        let windowTitle = session.identity.windowIdentifier.appleScriptEscaped
        let commandLine = session.identity.commandLine.appleScriptEscaped

        var matchConditions: [String] = []

        if !ttyId.isEmpty {
            matchConditions.append("tty of eachSession is \"\(ttyId)\"")
        }

        if !commandLine.isEmpty {
            matchConditions.append("sessionName contains \"\(commandLine)\"")
        }

        if matchConditions.isEmpty {
            matchConditions.append("sessionName contains \"\(windowTitle)\"")
            matchConditions.append("windowName is \"\(windowTitle)\"")
        } else {
            matchConditions.append("sessionName contains \"\(windowTitle)\"")
            matchConditions.append("windowName is \"\(windowTitle)\"")
        }

        let allConditions = matchConditions.joined(separator: " or ")

        return """
        tell application "iTerm"
            set targetSession to null
            set targetWindow to null
            repeat with eachWindow in windows
                repeat with eachTab in tabs of eachWindow
                    repeat with eachSession in sessions of eachTab
                        set sessionName to ""
                        try
                            set sessionName to name of eachSession
                        end try

                        set windowName to ""
                        try
                            set windowName to name of eachWindow
                        end try

                        if (\(allConditions)) then
                            set targetSession to eachSession
                            set targetWindow to eachWindow
                            exit repeat
                        end if
                    end repeat
                    if targetSession is not null then
                        exit repeat
                    end if
                end repeat
                if targetSession is not null then
                    exit repeat
                end if
            end repeat

            if targetSession is not null then
                activate
                delay 0.05
                select targetSession
            else if targetWindow is not null then
                activate
                delay 0.05
                try
                    select tab 1 of targetWindow
                end try
            else
                activate
            end if
        end tell
        """
    }
}

private extension String {
    var appleScriptEscaped: String {
        replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: " ")
    }
}
