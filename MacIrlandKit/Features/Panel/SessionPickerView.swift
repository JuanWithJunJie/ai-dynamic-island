import SwiftUI

public struct SessionPickerView: View {
    private let sessions: [TaskSession]
    private let selectedSessionID: TaskSession.ID?
    private let onSelect: (TaskSession) -> Void
    private let emptyStateMessage: String

    public init(
        sessions: [TaskSession],
        selectedSessionID: TaskSession.ID?,
        emptyStateMessage: String = "当前没有可查看的 AI CLI 会话。",
        onSelect: @escaping (TaskSession) -> Void
    ) {
        self.sessions = sessions
        self.selectedSessionID = selectedSessionID
        self.emptyStateMessage = emptyStateMessage
        self.onSelect = onSelect
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PanelSectionHeader("其他会话", subtitle: "同一时期内的其他等待会话。")

            if sessions.isEmpty {
                Text(emptyStateMessage)
                    .font(.subheadline)
                    .foregroundStyle(MacIrlandPalette.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(MacIrlandPalette.surfaceMuted, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            } else {
                VStack(spacing: 10) {
                    ForEach(sessions) { session in
                        Button {
                            onSelect(session)
                        } label: {
                            SessionPickerRow(
                                session: session,
                                isSelected: session.id == selectedSessionID
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

private struct SessionPickerRow: View {
    let session: TaskSession
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            StatusSpriteView(status: session.status)

            VStack(alignment: .leading, spacing: 4) {
                Text(session.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(session.compactSessionSubtitle)
                    .font(.caption)
                    .foregroundStyle(MacIrlandPalette.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if session.isAwaitingUser {
                MetaChip("等待处理", systemImage: "hand.raised.fill", tint: .orange)
            } else {
                Text(session.relativeLastActiveText)
                    .font(.caption)
                    .foregroundStyle(MacIrlandPalette.tertiaryText)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(backgroundStyle, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(isSelected ? IslandAccent.color(for: session.status).opacity(0.45) : MacIrlandPalette.subtleBorder, lineWidth: 1.5)
        )
    }

    private var backgroundStyle: some ShapeStyle {
        if isSelected {
            return AnyShapeStyle(IslandAccent.color(for: session.status).opacity(0.14))
        }
        return AnyShapeStyle(MacIrlandPalette.surfaceMuted)
    }
}
