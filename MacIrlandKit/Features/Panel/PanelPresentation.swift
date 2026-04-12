import Foundation

// MARK: - App Readiness Model

/// Unified user-facing readiness representation for the product layer.
/// Answers: is the app ready, partially ready, or blocked — and what to do next.
public enum AppReadinessLevel: String, Sendable {
    case ready
    case blocked
    case noSession
    case limitedReply
    case partialObservation
}

public struct AppReadiness: Sendable {
    public let level: AppReadinessLevel
    public let title: String
    public let explanation: String
    public let nextAction: String?

    public init(level: AppReadinessLevel, title: String, explanation: String, nextAction: String?) {
        self.level = level
        self.title = title
        self.explanation = explanation
        self.nextAction = nextAction
    }
}

public extension TaskStateStore {
    /// Produces a unified user-facing readiness assessment.
    /// This is the single source of truth for the onboarding / blocked-state UI.
    var appReadiness: AppReadiness {
        if capabilityStatus.observationBlocked {
            return AppReadiness(
                level: .blocked,
                title: "无法读取终端会话",
                explanation: capabilityStatus.explanation,
                nextAction: "打开系统设置 → 隐私与安全 → 自动化 → 允许 MacIrland 访问 Terminal"
            )
        }

        if let session = selectedSession {
            if session.replyCapability.canSendSafely {
                return AppReadiness(
                    level: .ready,
                    title: "可以继续",
                    explanation: "当前会话等待你的输入",
                    nextAction: nil
                )
            } else {
                return AppReadiness(
                    level: .limitedReply,
                    title: "当前会话暂时无法回复",
                    explanation: session.replyCapability.reason,
                    nextAction: nil
                )
            }
        }

        // No selected session, but observation is working
        if primaryPanelSessions.isEmpty {
            if observationDiagnostics.sessions.contains(where: { $0.recognizedCLIKind == nil }) {
                return AppReadiness(
                    level: .partialObservation,
                    title: "检测到终端会话但未识别为 Claude Code",
                    explanation: "本轮已读取到终端 session，但未命中 Claude Code 识别规则。",
                    nextAction: "确认 Claude Code 正在 Terminal 或 iTerm 中运行"
                )
            }
            return AppReadiness(
                level: .noSession,
                title: "还没有 Claude Code 会话",
                explanation: "MacIrland 正在运行，但尚未检测到 Claude Code 会话。",
                nextAction: "在 Terminal 或 iTerm 中启动 Claude Code"
            )
        }

        return AppReadiness(
            level: .noSession,
            title: "还没有 Claude Code 会话",
            explanation: "当前没有需要处理的 Claude Code 会话。",
            nextAction: nil
        )
    }
}

public extension TaskSession {
    var compactSessionSubtitle: String {
        if isAwaitingUser {
            return primaryGuidanceText
        }

        return summary
    }

    func timelinePreviewEntries(limit: Int = 3) -> [SessionHistoryEntry] {
        Array(timelineEntries.prefix(limit))
    }
}

public extension CapabilityStatus {
    var panelDiagnosticsSummary: String {
        if observationBlocked {
            return "终端读取失败，展开诊断查看权限或识别问题。"
        }

        return explanation
    }

    var showsDiagnosticsExpandedByDefault: Bool {
        observationBlocked
    }
}
