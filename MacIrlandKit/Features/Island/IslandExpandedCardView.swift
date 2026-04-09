import SwiftUI

public struct IslandExpandedCardView: View {
    let presentation: HighlightedIslandPresentation
    let actionResult: ReplyValidationResult?
    let openPanel: () -> Void
    let triggerPrimaryAction: () -> Void
    let dismiss: () -> Void

    public init(
        presentation: HighlightedIslandPresentation,
        actionResult: ReplyValidationResult?,
        openPanel: @escaping () -> Void,
        triggerPrimaryAction: @escaping () -> Void,
        dismiss: @escaping () -> Void
    ) {
        self.presentation = presentation
        self.actionResult = actionResult
        self.openPanel = openPanel
        self.triggerPrimaryAction = triggerPrimaryAction
        self.dismiss = dismiss
    }

    public var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: openPanel) {
                VStack(alignment: .leading, spacing: 18) {
                    Spacer(minLength: 0)

                    HStack(alignment: .center, spacing: 14) {
                        StatusSpriteView(status: presentation.status)

                        VStack(alignment: .leading, spacing: 6) {
                            Text(presentation.titleText)
                                .font(.system(size: 17, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)

                            Text(presentation.summaryText)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(MacIrlandPalette.secondaryText)
                                .lineLimit(2)
                        }

                        Spacer(minLength: 16)

                        VStack(alignment: .trailing, spacing: 8) {
                            MetaChip(presentation.sourceText, tint: presentation.accentColor)
                            Text(presentation.timeText)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(MacIrlandPalette.tertiaryText)
                        }
                    }

                    HStack(spacing: 12) {
                        if let actionTitle = presentation.primaryActionTitle {
                            Button(actionTitle, action: triggerPrimaryAction)
                                .buttonStyle(.borderedProminent)
                                .tint(presentation.accentColor)
                        }

                        if let actionResult {
                            Text(actionResult.explanation)
                                .font(.caption)
                                .foregroundStyle(actionResult.canSend ? MacIrlandPalette.islandSuccess : MacIrlandPalette.islandWarning)
                                .lineLimit(1)
                        }
                    }
                }
                .padding(22)
                .frame(width: 860, height: 152, alignment: .bottomLeading)
                .background(MacIrlandPalette.islandSurface, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .strokeBorder(presentation.accentColor.opacity(0.18), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            HStack(spacing: 10) {
                Image(systemName: "speaker.wave.2.fill")
                Image(systemName: "gearshape.fill")
                Button(action: dismiss) {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.plain)
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white.opacity(0.8))
            .padding(18)
        }
        .accessibilityLabel(presentation.accessibilityLabel)
    }
}
