import SwiftUI

public enum MacIrlandPalette {
    public static let canvasTop = Color(red: 0.04, green: 0.05, blue: 0.08)
    public static let canvasBottom = Color(red: 0.02, green: 0.02, blue: 0.04)
    public static let surface = Color(red: 0.07, green: 0.08, blue: 0.11)
    public static let surfaceElevated = Color(red: 0.10, green: 0.11, blue: 0.15)
    public static let surfaceMuted = Color(red: 0.12, green: 0.13, blue: 0.17)
    public static let border = Color.white.opacity(0.08)
    public static let subtleBorder = Color.white.opacity(0.05)
    public static let secondaryText = Color.white.opacity(0.68)
    public static let tertiaryText = Color.white.opacity(0.48)
}

public enum PanelCardTone {
    case regular
    case elevated
    case subdued
}

public struct PanelCard<Content: View>: View {
    private let tone: PanelCardTone
    private let padding: CGFloat
    private let content: Content

    public init(
        tone: PanelCardTone = .regular,
        padding: CGFloat = 18,
        @ViewBuilder content: () -> Content
    ) {
        self.tone = tone
        self.padding = padding
        self.content = content()
    }

    public var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(backgroundColor, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: 1)
            )
            .shadow(color: .black.opacity(tone == .elevated ? 0.28 : 0.16), radius: tone == .elevated ? 28 : 18, y: 10)
    }

    private var backgroundColor: Color {
        switch tone {
        case .regular:
            return MacIrlandPalette.surface
        case .elevated:
            return MacIrlandPalette.surfaceElevated
        case .subdued:
            return MacIrlandPalette.surfaceMuted
        }
    }

    private var borderColor: Color {
        tone == .subdued ? MacIrlandPalette.subtleBorder : MacIrlandPalette.border
    }
}

public struct PanelSectionHeader: View {
    private let title: String
    private let subtitle: String?

    public init(_ title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 15, weight: .semibold, design: .default))
                .foregroundStyle(.white)

            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(MacIrlandPalette.secondaryText)
            }
        }
    }
}

public struct MetaChip: View {
    private let title: String
    private let systemImage: String?
    private let tint: Color?

    public init(_ title: String, systemImage: String? = nil, tint: Color? = nil) {
        self.title = title
        self.systemImage = systemImage
        self.tint = tint
    }

    public var body: some View {
        HStack(spacing: 6) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.caption2.weight(.semibold))
            }

            Text(title)
                .lineLimit(1)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(foregroundColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(backgroundColor, in: Capsule())
        .overlay(
            Capsule()
                .strokeBorder((tint ?? Color.white).opacity(0.08), lineWidth: 1)
        )
    }

    private var foregroundColor: Color {
        tint ?? .white.opacity(0.86)
    }

    private var backgroundColor: Color {
        (tint ?? .white).opacity(tint == nil ? 0.08 : 0.18)
    }
}
