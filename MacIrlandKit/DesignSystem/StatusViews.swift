import SwiftUI

public enum IslandAccent {
    public static func color(for status: TaskStatus) -> Color {
        switch status {
        case .running:
            return .blue
        case .waitingInput, .replyAvailable:
            return .orange
        case .alert, .failed:
            return .red
        case .completed:
            return .green
        case .contextLost:
            return .gray
        case .discovered, .recognizing:
            return .secondary
        }
    }
}

public struct StatusBadge: View {
    private let status: TaskStatus

    public init(status: TaskStatus) {
        self.status = status
    }

    public var body: some View {
        Text(status.label)
            .font(.caption.weight(.semibold))
            .foregroundStyle(IslandAccent.color(for: status))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(IslandAccent.color(for: status).opacity(0.14), in: Capsule())
    }
}

public struct StatusSpriteView: View {
    private let status: TaskStatus

    public init(status: TaskStatus) {
        self.status = status
    }

    public var body: some View {
        Text(sprite)
            .font(.system(size: 28, weight: .bold, design: .monospaced))
            .foregroundStyle(IslandAccent.color(for: status))
            .frame(width: 42, height: 42)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var sprite: String {
        switch status {
        case .running:
            return ">_"
        case .waitingInput:
            return "?_"
        case .replyAvailable:
            return "<_"
        case .alert, .failed:
            return "!_"
        case .completed:
            return "✓_"
        case .contextLost:
            return "~_"
        case .discovered, .recognizing:
            return "._"
        }
    }
}
