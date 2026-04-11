import SwiftUI

public struct IslandStatusStripView: View {
    @Bindable var store: TaskStateStore
    private let action: () -> Void

    public init(store: TaskStateStore, action: @escaping () -> Void) {
        self.store = store
        self.action = action
    }

    public var body: some View {
        let presentation = CompactIslandPresentation(
            summary: store.summary,
            preferredSession: store.preferredIslandSession,
            secondaryCount: store.secondaryIslandAttentionCount(excluding: store.preferredIslandSession?.id),
            totalCountOverride: store.hoverExpandSessionCount
        )

        let iconStatus: AnimatedStatus = store.preferredIslandSession?.status.animatedStatus ?? .idle

        Button(action: action) {
            HStack(spacing: 8) {
                AnimatedStatusIcon(status: iconStatus)
                Spacer()
                Text(presentation.countText)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(width: 300, alignment: .leading)
            .background(MacIrlandPalette.islandSurface, in: Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(
                        presentation.isAlert ? Color.red.opacity(0.5) : presentation.accentColor.opacity(0.28),
                        lineWidth: presentation.isAlert ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(presentation.accessibilityLabel)
    }
}
