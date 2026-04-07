import SwiftUI

public struct IslandCompactView: View {
    private let session: TaskSession?

    public init(session: TaskSession?) {
        self.session = session
    }

    public var body: some View {
        Group {
            if let session {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top, spacing: 14) {
                        StatusSpriteView(status: session.status)

                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(session.title)
                                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white)
                                    .lineLimit(2)
                                Spacer(minLength: 8)
                                StatusBadge(status: session.status)
                            }

                            Text(session.summary)
                                .font(.subheadline)
                                .foregroundStyle(MacIrlandPalette.secondaryText)
                                .lineLimit(3)
                        }
                    }

                    HStack(spacing: 8) {
                        MetaChip(session.sourceCLI.displayName, systemImage: "cpu")
                        MetaChip(session.terminalDisplayName, systemImage: "rectangle.on.rectangle")
                        MetaChip(session.relativeLastActiveText, systemImage: "clock")
                        if session.isAwaitingUser {
                            MetaChip("需要处理", systemImage: "hand.raised.fill", tint: .orange)
                        }
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Text("No Active Tasks")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                    Text("当前没有检测到 AI CLI 活跃任务，启动 Claude Code、Codex 或 Gemini CLI 后会自动出现在这里。")
                        .font(.subheadline)
                        .foregroundStyle(MacIrlandPalette.secondaryText)
                }
            }
        }
    }
}
