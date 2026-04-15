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

        let tty = session.identity.ttyIdentifier ?? "nil"
        let window = session.identity.windowIdentifier
        let sessionName = session.identity.sessionName
        let hookSessionID = session.identity.hookSessionID ?? "nil"
        NSLog("TerminalJumpService: Jumping. app=%@ tty=%@ hookSessionID=%@ sessionName=%@", appIdentifier, tty, hookSessionID, sessionName)

        // Log the full script for debugging (append mode)
        let logMsg = """
        --- JUMP SCRIPT for \(appIdentifier) ---
        tty: \(tty)
        hookSessionID: \(hookSessionID)
        sessionName: \(sessionName)
        window: \(window)
        --- AppleScript ---
        \(script)
        --- END ---

        """
        if let data = logMsg.data(using: .utf8),
           let file = try? FileHandle(forWritingTo: URL(fileURLWithPath: "/tmp/macirland-jump-detail.log")) {
            file.seekToEndOfFile()
            file.write(data)
            file.closeFile()
        }

        let result = AppleScriptRunner.run(script: script)
        if let error = result.errorDescription {
            NSLog("TerminalJumpService: AppleScript failed - %@", error)
        } else {
            NSLog("TerminalJumpService: Jump completed")
        }
    }

    private static func terminalJumpScript(session: TaskSession) -> String {
        let tty = session.identity.ttyIdentifier
        let windowIdentifier = session.identity.windowIdentifier

        // Extract TERM_SESSION_ID from windowIdentifier for use as the unique session identifier.
        // WindowIdentifier format: "windowName — ✳ Claude Code — subprocessName TERM_SESSION_ID=xxx — dimensions"
        // TERM_SESSION_ID is the unique identifier for each Terminal tab/session.
        let termSessionID: String
        if let range = windowIdentifier.range(of: "TERM_SESSION_ID=") {
            let startIdx = range.upperBound
            let endIdx = windowIdentifier[startIdx...].firstIndex(of: " ") ?? windowIdentifier.endIndex
            termSessionID = String(windowIdentifier[startIdx..<endIdx])
        } else {
            termSessionID = ""
        }

        // Build match conditions using TERM_SESSION_ID as primary identifier.
        // For Terminal: TERM_SESSION_ID is in the window name (not tab name), so we check windowName.
        // Fall back to tty only if TERM_SESSION_ID is not available.
        let matchCondition: String

        if !termSessionID.isEmpty {
            // Primary: match by TERM_SESSION_ID in the window name (which contains it)
            // Use direct variable comparison in AppleScript
            matchCondition = "(windowName contains \"\(termSessionID)\")"
        } else if let tty, !tty.isEmpty {
            // Fallback: match by tty only
            matchCondition = "(tty of eachTab is \"\(tty)\")"
        } else {
            // Last resort: match by subprocess in process list
            matchCondition = "(processes of eachTab as text contains \"claude\")"
        }

        return """
        tell application "Terminal"
            set targetTab to null
            set targetWindow to null
            set debugInfo to ""

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

                    set tabTTY to ""
                    try
                        set tabTTY to tty of eachTab
                    end try

                    set tabDescription to ""
                    try
                        set tabDescription to description of eachTab
                    end try

                    set tabProcess to ""
                    try
                        set tabProcess to processes of eachTab as text
                    end try

                    set matchResult to false
                    try
                        set matchResult to (\(matchCondition))
                    end try

                    set debugInfo to debugInfo & "Window: " & windowName & " | desc: " & tabDescription & " | tty: " & tabTTY & " | match: " & (matchResult as string) & return

                    if (matchResult) then
                        set targetTab to eachTab
                        set targetWindow to eachWindow
                        set debugInfo to debugInfo & "  --> MATCHED!" & return
                        exit repeat
                    end if
                end repeat

                if targetTab is not null then
                    exit repeat
                end if
            end repeat

            -- Log debug info
            try
                do shell script "echo " & quoted form of debugInfo & " >> /tmp/macirland-jump-debug.txt"
            end try

            if targetTab is not null then
                activate
                delay 0.05
                set selected of targetTab to true
                set frontmost of targetWindow to true
            end if
        end tell
        """
    }

    private static func iTermJumpScript(session: TaskSession) -> String {
        // iTerm2 session jump: TTY-first, fallback to sessionName.
        // TTY is stable from hook events; sessionName can be stale.
        let targetSessionName = session.identity.sessionName.appleScriptEscaped
        let targetTTY = (session.identity.ttyIdentifier ?? "").appleScriptEscaped

        return """
        tell application "iTerm"
            set targetSession to null
            set targetTab to null
            set targetWindow to null
            set debugInfo to ""

            repeat with eachWindow in windows
                set windowID to ""
                set windowName to ""
                try
                    set windowID to id of eachWindow as string
                end try
                try
                    set windowName to name of eachWindow
                end try

                repeat with eachTab in tabs of eachWindow
                    repeat with eachSession in sessions of eachTab
                        set sessionName to ""
                        set sessionTTY to ""
                        try
                            set sessionName to name of eachSession
                        end try
                        try
                            set sessionTTY to tty of eachSession
                        end try

                        -- TTY-first matching: use TTY as primary key (stable from hook).
                        -- Fall back to sessionName if TTY is not available.
                        set matchResult to false
                        if "\(targetTTY)" is not "" then
                            if sessionTTY is "\(targetTTY)" then
                                set matchResult to true
                            end if
                        end if
                        if matchResult is false and "\(targetSessionName)" is not "" then
                            if sessionName is "\(targetSessionName)" then
                                set matchResult to true
                            end if
                        end if

                        set debugInfo to debugInfo & "Window[id=" & windowID & ",name=" & windowName & "] | tab sessions: " & (count of sessions of eachTab) as string & " | session: " & sessionName & " | tty: " & sessionTTY & " | target: '\(targetSessionName)' x '\(targetTTY)' | match: " & (matchResult as string) & return

                        if (matchResult) then
                            set targetSession to eachSession
                            set targetTab to eachTab
                            set targetWindow to eachWindow
                            set debugInfo to debugInfo & "  --> MATCHED! window[id=" & windowID & "]" & return
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

            -- Log debug info
            try
                do shell script "echo " & quoted form of debugInfo & " >> /tmp/macirland-jump-debug.txt"
            end try

            -- Activate iTerm2 first so the app is frontmost
            activate
            delay 0.1

            if targetWindow is not null then
                -- Switch to the correct tab before bringing window front
                if targetTab is not null then
                    try
                        set current tab of targetWindow to targetTab
                    end try
                end if

                -- Bring the window to front
                try
                    tell targetWindow to select
                end try
                try
                    set frontmost of targetWindow to true
                end try
                delay 0.05
            end if

            -- Select the session inside its tab
            if targetSession is not null then
                try
                    tell targetSession to select
                end try
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
