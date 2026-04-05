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

public struct MockReplyBridgeService: ReplyBridging {
    public init() {}

    public func validateReply(for session: TaskSession, message: String) -> ReplyValidationResult {
        guard !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return ReplyValidationResult(canSend: false, explanation: "回复内容不能为空。")
        }

        guard session.bridgeTarget != nil else {
            return ReplyValidationResult(canSend: false, explanation: "当前没有可用的目标会话。")
        }

        guard session.replyCapability.status != .unavailable else {
            return ReplyValidationResult(canSend: false, explanation: session.replyCapability.reason)
        }

        return ReplyValidationResult(
            canSend: session.replyCapability.status == .available,
            explanation: session.replyCapability.status == .available ? "可直接发送。" : "需要在真实桥接接入后再发送，目前仅做确认。"
        )
    }

    public func sendReply(to session: TaskSession, message: String) -> ReplyValidationResult {
        let validation = validateReply(for: session, message: message)
        guard validation.canSend else {
            return validation
        }

        return ReplyValidationResult(canSend: true, explanation: "已通过 mock 桥接发送到 \(session.replyCapability.targetDescription)。")
    }
}
