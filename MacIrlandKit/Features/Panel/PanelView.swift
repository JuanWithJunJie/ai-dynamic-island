import SwiftUI

public struct PanelView: View {
    @Bindable private var viewModel: TaskStateStore
    @State private var lastActionResult: ReplyValidationResult?
    @State private var diagnosticsExpanded: Bool

    public init(viewModel: TaskStateStore) {
        self.viewModel = viewModel
        _diagnosticsExpanded = State(initialValue: viewModel.capabilityStatus.showsDiagnosticsExpandedByDefault)
    }

    public var body: some View {
        ZStack {
            LinearGradient(
                colors: [MacIrlandPalette.canvasTop, MacIrlandPalette.canvasBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    PanelHeaderView(
                        summary: viewModel.summary,
                        topSession: viewModel.topSession,
                        capabilityStatus: viewModel.capabilityStatus
                    )

                    if let session = viewModel.selectedSession {
                        PanelCard(tone: .elevated, padding: 16) {
                            SessionDetailView(
                                viewModel: viewModel,
                                session: session,
                                lastActionResult: $lastActionResult
                            )
                        }
                    } else {
                        PanelCard(tone: .elevated, padding: 16) {
                            EmptyWorkspaceView(
                                summary: viewModel.summary,
                                topSession: viewModel.topSession,
                                emptyStateMessage: sessionEmptyStateMessage
                            )
                        }
                    }

                    PanelCard(tone: .subdued, padding: 14) {
                        SessionPickerView(
                            sessions: viewModel.sessions,
                            selectedSessionID: viewModel.selectedSessionID,
                            emptyStateMessage: sessionEmptyStateMessage,
                            onSelect: handleSelection
                        )
                    }

                    PanelCard(tone: .subdued, padding: 14) {
                        DiagnosticsDisclosureView(
                            isExpanded: $diagnosticsExpanded,
                            session: viewModel.selectedSession,
                            capabilityStatus: viewModel.capabilityStatus,
                            observationDiagnostics: viewModel.observationDiagnostics
                        )
                    }
                }
                .padding(18)
            }
        }
        .frame(minWidth: 640, minHeight: 560)
        .onChange(of: viewModel.capabilityStatus.observationBlocked) { _, isBlocked in
            if isBlocked {
                diagnosticsExpanded = true
            }
        }
    }

    private func handleSelection(_ session: TaskSession) {
        viewModel.selectSession(session)
        lastActionResult = nil
    }

    private var sessionEmptyStateMessage: String {
        if viewModel.capabilityStatus.observationBlocked {
            return "当前没有成功读取到 Claude Code 会话。请确认 Terminal / iTerm 自动化权限已授权，系统会在下一轮自动刷新时重试。"
        }

        if viewModel.observationDiagnostics.sessions.contains(where: { $0.recognizedCLIKind == nil }) {
            return "本轮已经读到终端 session，但还没有命中 Claude Code 识别规则。请展开下方诊断，查看 raw command / windowTitle / reason。"
        }

        return "当前没有可查看的 AI CLI 会话。"
    }
}

private struct PanelHeaderView: View {
    let summary: AppTaskSummary
    let topSession: TaskSession?
    let capabilityStatus: CapabilityStatus

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text("MacIrland")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(topSession?.compactSessionSubtitle ?? "这里是 island 的二级详情层，用来继续处理当前会话。")
                    .font(.footnote)
                    .foregroundStyle(MacIrlandPalette.secondaryText)
                    .lineLimit(2)
            }

            Spacer()
        }
    }
}

private struct EmptyWorkspaceView: View {
    let summary: AppTaskSummary
    let topSession: TaskSession?
    let emptyStateMessage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PanelSectionHeader("主工作区", subtitle: "这里是 island 的二级详情层，用来继续处理当前会话。")

            Text("还没有可处理的会话")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            Text(emptyStateMessage)
                .font(.subheadline)
                .foregroundStyle(MacIrlandPalette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct DiagnosticsDisclosureView: View {
    @Binding var isExpanded: Bool
    let session: TaskSession?
    let capabilityStatus: CapabilityStatus
    let observationDiagnostics: ObservationDiagnostics

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            DiagnosticsSectionView(
                session: session,
                capabilityStatus: capabilityStatus,
                observationDiagnostics: observationDiagnostics
            )
            .padding(.top, 14)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("诊断")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                    Spacer()
                    Text(isExpanded ? "收起" : "展开")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(MacIrlandPalette.tertiaryText)
                }

                Text(capabilityStatus.panelDiagnosticsSummary)
                    .font(.caption)
                    .foregroundStyle(MacIrlandPalette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .tint(.white)
    }
}
