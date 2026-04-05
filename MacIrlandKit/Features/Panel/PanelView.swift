import SwiftUI

public struct PanelView: View {
    @Bindable private var viewModel: TaskStateStore
    @State private var lastActionResult: ReplyValidationResult?

    public init(viewModel: TaskStateStore) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                IslandCompactView(session: viewModel.topSession)
                OverviewSectionView(summary: viewModel.summary)

                if let session = viewModel.topSession {
                    sessionSection(session)
                }

                DiagnosticsSectionView(session: viewModel.topSession, capabilityStatus: viewModel.capabilityStatus)
            }
            .padding(20)
        }
        .frame(minWidth: 520, minHeight: 640)
        .toolbar {
            Button("刷新") {
                viewModel.refresh()
            }
        }
    }

    @ViewBuilder
    private func sessionSection(_ session: TaskSession) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("当前任务")
                .font(.headline)

            VStack(alignment: .leading, spacing: 10) {
                Text(session.title)
                    .font(.title3.weight(.semibold))
                Text(session.summary)
                    .foregroundStyle(.secondary)

                if let target = session.bridgeTarget {
                    Text("目标会话：\(target.displayName)")
                        .font(.subheadline)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("关键事件")
                        .font(.subheadline.weight(.medium))
                    ForEach(session.recentEvents) { event in
                        Text("• \(event.message)")
                            .font(.subheadline)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("最近消息")
                        .font(.subheadline.weight(.medium))
                    ForEach(session.recentMessages) { message in
                        Text(message.text)
                            .font(.subheadline)
                            .foregroundStyle(message.isError ? .red : .primary)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("快捷回复")
                        .font(.subheadline.weight(.medium))
                    FlowLayout(spacing: 8) {
                        ForEach(session.quickActions, id: \.self) { action in
                            Button(action.title) {
                                if action == .customText {
                                    lastActionResult = viewModel.sendDraftReply(for: session)
                                } else {
                                    viewModel.draftReply = action.defaultMessage
                                    lastActionResult = viewModel.performQuickAction(action, for: session)
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("自由输入")
                        .font(.subheadline.weight(.medium))
                    TextField("输入要发送给 CLI 的回复", text: $viewModel.draftReply, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                    Button("发送文本") {
                        lastActionResult = viewModel.sendDraftReply(for: session)
                    }
                    .buttonStyle(.borderedProminent)
                }

                if let lastActionResult {
                    Text(lastActionResult.explanation)
                        .font(.footnote)
                        .foregroundStyle(lastActionResult.canSend ? .green : .orange)
                }
            }
            .padding(16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }
}

private struct FlowLayout<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder let content: Content

    var body: some View {
        content
    }
}
