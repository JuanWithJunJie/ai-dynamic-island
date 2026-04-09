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
            secondaryCount: store.secondaryIslandAttentionCount(excluding: store.preferredIslandSession?.id)
        )

        Button(action: action) {
            HStack(spacing: 10) {
                StatusSpriteView(status: store.topSession?.status ?? .completed)
                Text(presentation.statusText)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                if let secondary = presentation.secondaryText {
                    Text(secondary)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                }
                Spacer(minLength: 12)
                Text(presentation.countText)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.86))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .frame(width: 520, alignment: .leading)
            .background(MacIrlandPalette.islandSurface, in: Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(presentation.accentColor.opacity(0.28), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(presentation.accessibilityLabel)
    }
}
