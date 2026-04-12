import SwiftUI

public enum AnimatedStatus: String, Sendable {
    case idle      // no active session
    case running   // actively working
    case completed // task finished
    case waiting   // waiting for user input / reply
}

public struct AnimatedStatusIcon: View {
    public let status: AnimatedStatus

    public init(status: AnimatedStatus) {
        self.status = status
    }

    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(MacIrlandPalette.surfaceMuted)

            switch status {
            case .idle:
                IdleSpriteContent()
            case .running:
                RunningSpriteContent()
            case .completed:
                CompletedSpriteContent()
            case .waiting:
                WaitingSpriteContent()
            }
        }
        .frame(width: 28, height: 28)
    }
}

struct IdleSpriteContent: View {
    @State private var blink = false

    var body: some View {
        Image(systemName: "terminal.fill")
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(blink ? Color.green.opacity(0.7) : Color.green.opacity(0.3))
            .onAppear {
                withAnimation(Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    blink = true
                }
            }
    }
}

struct RunningSpriteContent: View {
    @State private var dotCount = 1

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: "terminal.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.green)

            HStack(spacing: 2) {
                ForEach(0..<4, id: \.self) { i in
                    Circle()
                        .fill(Color.white)
                        .frame(width: 3, height: 3)
                        .opacity(i < dotCount ? 1.0 : 0.2)
                }
            }
        }
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 0.18, repeats: true) { timer in
                Task { @MainActor in
                    dotCount = (dotCount % 4) + 1
                }
            }
        }
    }
}

struct CompletedSpriteContent: View {
    var body: some View {
        Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(Color.orange)
    }
}

struct WaitingSpriteContent: View {
    @State private var pulse = false

    var body: some View {
        Image(systemName: "ellipsis.circle.fill")
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(Color.orange.opacity(pulse ? 1.0 : 0.5))
            .onAppear {
                withAnimation(Animation.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
    }
}

// MARK: - Convenience extensions

extension TaskStatus {
    public var animatedStatus: AnimatedStatus {
        switch self {
        case .running:
            return .running
        case .completed:
            return .completed
        case .waitingInput, .replyAvailable:
            return .waiting
        default:
            return .idle
        }
    }
}

extension AnimatedStatus {
    public var statusColor: Color {
        switch self {
        case .idle:
            return .green.opacity(0.6)
        case .running:
            return .green
        case .completed:
            return .orange
        case .waiting:
            return .orange
        }
    }
}

struct AnimatedStatusIcon_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            HStack(spacing: 20) {
                AnimatedStatusIcon(status: .idle)
                AnimatedStatusIcon(status: .running)
                AnimatedStatusIcon(status: .waiting)
                AnimatedStatusIcon(status: .completed)
            }
        }
        .padding()
        .background(Color.black)
    }
}
