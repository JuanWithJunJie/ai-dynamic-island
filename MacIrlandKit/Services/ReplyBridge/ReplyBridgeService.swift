import Foundation

public struct ReplyValidationResult: Sendable {
    public let canSend: Bool
    public let explanation: String

    public init(canSend: Bool, explanation: String) {
        self.canSend = canSend
        self.explanation = explanation
    }
}

public protocol ReplyBridging: Sendable {
    func validateReply(for session: TaskSession, message: String) -> ReplyValidationResult
    func sendReply(to session: TaskSession, message: String) -> ReplyValidationResult
}

public struct ReplyBridgeService: ReplyBridging {
    public init() {}

    public func validateReply(for session: TaskSession, message: String) -> ReplyValidationResult {
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedMessage.isEmpty == false else {
            return ReplyValidationResult(canSend: false, explanation: "回复内容不能为空。")
        }

        guard session.sourceCLI == .claudeCode else {
            return ReplyValidationResult(canSend: false, explanation: "当前仅支持向 Claude Code 会话发送回复。")
        }

        guard let bridgeTarget = session.bridgeTarget else {
            return ReplyValidationResult(canSend: false, explanation: "当前没有可用的目标会话。")
        }

        guard session.replyCapability.status != .unavailable else {
            return ReplyValidationResult(canSend: false, explanation: session.replyCapability.reason)
        }

        guard let writer = writer(for: session) else {
            return ReplyValidationResult(canSend: false, explanation: unsupportedTerminalExplanation(for: session))
        }

        guard targetLooksConsistent(session: session, bridgeTarget: bridgeTarget) else {
            return ReplyValidationResult(canSend: false, explanation: "目标 Claude Code 会话已变化或不存在，请刷新后重试。")
        }

        return writer.validateTarget(for: session, message: trimmedMessage)
    }

    public func sendReply(to session: TaskSession, message: String) -> ReplyValidationResult {
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        let validation = validateReply(for: session, message: trimmedMessage)
        guard validation.canSend else {
            return validation
        }

        guard let writer = writer(for: session) else {
            return ReplyValidationResult(canSend: false, explanation: unsupportedTerminalExplanation(for: session))
        }

        return writer.send(message: trimmedMessage, to: session)
    }

    private func writer(for session: TaskSession) -> (any AppleScriptReplyWriting)? {
        switch session.identity.terminalAppIdentifier {
        case "com.apple.Terminal":
            return TerminalReplyWriter()
        case "com.googlecode.iterm2":
            return ITermReplyWriter()
        default:
            return nil
        }
    }

    private func targetLooksConsistent(session: TaskSession, bridgeTarget: BridgeTarget) -> Bool {
        let windowIdentifier = session.identity.windowIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        let terminalContext = bridgeTarget.terminalContext.trimmingCharacters(in: .whitespacesAndNewlines)

        guard windowIdentifier.isEmpty == false, terminalContext.isEmpty == false else {
            return false
        }

        return windowIdentifier == terminalContext
    }

    private func unsupportedTerminalExplanation(for session: TaskSession) -> String {
        switch session.identity.terminalAppIdentifier {
        case "com.apple.Terminal", "com.googlecode.iterm2":
            return "当前会话暂时不可发送，请刷新后重试。"
        default:
            return "当前仅支持通过 Terminal 或 iTerm 向 Claude Code 会话发送回复。"
        }
    }
}

public typealias MockReplyBridgeService = ReplyBridgeService

private protocol AppleScriptReplyWriting: Sendable {
    func validateTarget(for session: TaskSession, message: String) -> ReplyValidationResult
    func send(message: String, to session: TaskSession) -> ReplyValidationResult
}

private extension AppleScriptReplyWriting {
    func validateTarget(for session: TaskSession, message: String) -> ReplyValidationResult {
        guard session.replyCapability.status == .available else {
            return ReplyValidationResult(canSend: false, explanation: session.replyCapability.reason)
        }

        return ReplyValidationResult(canSend: true, explanation: "可直接发送到 Claude Code 终端会话。")
    }
}

private struct TerminalReplyWriter: AppleScriptReplyWriting {
    func send(message: String, to session: TaskSession) -> ReplyValidationResult {
        let runner = AppleScriptRunner.run(script: script(message: message, session: session))
        if let errorDescription = runner.errorDescription {
            return ReplyValidationResult(canSend: false, explanation: explanation(for: errorDescription))
        }

        return ReplyValidationResult(canSend: true, explanation: "已发送到 Terminal 中的 Claude Code 会话。")
    }

    private func script(message: String, session: TaskSession) -> String {
        let ttyCheck = session.identity.ttyIdentifier.map { "tty of eachTab is \"\($0.appleScriptEscaped)\"" } ?? "false"
        let windowTitle = session.identity.windowIdentifier.appleScriptEscaped
        let targetMessage = message.appleScriptEscaped

        return """
        tell application "Terminal"
            set didSend to false
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

                    if ((\(ttyCheck)) or tabName is "\(windowTitle)" or windowName is "\(windowTitle)") then
                        do script "\(targetMessage)" in eachTab
                        set didSend to true
                        exit repeat
                    end if
                end repeat

                if didSend then
                    exit repeat
                end if
            end repeat

            if didSend is false then error "TARGET_NOT_FOUND"
        end tell
        """
    }

    private func explanation(for errorDescription: String) -> String {
        if errorDescription.contains("TARGET_NOT_FOUND") {
            return "目标 Claude Code 会话已变化或不存在，请刷新后重试。"
        }
        if errorDescription.localizedCaseInsensitiveContains("not authorized") || errorDescription.localizedCaseInsensitiveContains("not permitted") {
            return "无法控制 Terminal。请在系统设置的自动化权限中允许 MacIrland 访问 Terminal 后重试。"
        }
        return "通过 Terminal 发送回复失败：\(errorDescription)"
    }
}

private struct ITermReplyWriter: AppleScriptReplyWriting {
    func send(message: String, to session: TaskSession) -> ReplyValidationResult {
        let runner = AppleScriptRunner.run(script: script(message: message, session: session))
        if let errorDescription = runner.errorDescription {
            return ReplyValidationResult(canSend: false, explanation: explanation(for: errorDescription))
        }

        return ReplyValidationResult(canSend: true, explanation: "已发送到 iTerm 中的 Claude Code 会话。")
    }

    private func script(message: String, session: TaskSession) -> String {
        let ttyCheck = session.identity.ttyIdentifier.map { "tty of eachSession is \"\($0.appleScriptEscaped)\"" } ?? "false"
        let windowTitle = session.identity.windowIdentifier.appleScriptEscaped
        let targetMessage = message.appleScriptEscaped

        return """
        tell application "iTerm"
            set didSend to false
            repeat with eachWindow in windows
                set windowName to ""
                try
                    set windowName to name of eachWindow
                end try

                repeat with eachTab in tabs of eachWindow
                    repeat with eachSession in sessions of eachTab
                        set sessionName to ""
                        try
                            set sessionName to name of eachSession
                        end try

                        if ((\(ttyCheck)) or sessionName is "\(windowTitle)" or windowName is "\(windowTitle)") then
                            tell eachSession
                                write text "\(targetMessage)"
                            end tell
                            set didSend to true
                            exit repeat
                        end if
                    end repeat

                    if didSend then
                        exit repeat
                    end if
                end repeat

                if didSend then
                    exit repeat
                end if
            end repeat

            if didSend is false then error "TARGET_NOT_FOUND"
        end tell
        """
    }

    private func explanation(for errorDescription: String) -> String {
        if errorDescription.contains("TARGET_NOT_FOUND") {
            return "目标 Claude Code 会话已变化或不存在，请刷新后重试。"
        }
        if errorDescription.localizedCaseInsensitiveContains("not authorized") || errorDescription.localizedCaseInsensitiveContains("not permitted") {
            return "无法控制 iTerm。请在系统设置的自动化权限中允许 MacIrland 访问 iTerm 后重试。"
        }
        return "通过 iTerm 发送回复失败：\(errorDescription)"
    }
}

private extension String {
    var appleScriptEscaped: String {
        replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: " ")
    }
}
