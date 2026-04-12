import SwiftUI
import AppKit

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
                                readiness: viewModel.appReadiness,
                                summary: viewModel.summary,
                                topSession: viewModel.topSession
                            )
                        }
                    }

                    PanelCard(tone: .subdued, padding: 14) {
                        SessionPickerView(
                            sessions: viewModel.primaryPanelSessions,
                            selectedSessionID: viewModel.selectedSessionID,
                            emptyStateMessage: viewModel.appReadiness.explanation,
                            onSelect: handleSelection
                        )
                    }

                    PanelCard(tone: .subdued, padding: 14) {
                        DiagnosticsDisclosureView(
                            isExpanded: $diagnosticsExpanded,
                            session: viewModel.selectedSession,
                            capabilityStatus: viewModel.capabilityStatus,
                            observationDiagnostics: viewModel.observationDiagnostics,
                            traySessionCount: viewModel.traySessions.count,
                            isTrayEligible: viewModel.hasMultipleRelevantSessions,
                            preferredIslandSessionStatus: viewModel.preferredIslandSession?.status
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

        return "当前没有可查看的 Claude Code 会话。"
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
    let readiness: AppReadiness
    let summary: AppTaskSummary
    let topSession: TaskSession?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PanelSectionHeader("主工作区", subtitle: readinessSubtitle)

            Text(readiness.title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(readinessTitleColor)

            Text(readiness.explanation)
                .font(.subheadline)
                .foregroundStyle(MacIrlandPalette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            if let nextAction = readiness.nextAction {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    Text(nextAction)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.orange.opacity(0.9))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.orange.opacity(0.2), lineWidth: 1)
                )

                if readiness.level == .blocked {
                    Button("打开系统设置") {
                        openAutomationSettings()
                    }
                    .buttonStyle(.bordered)
                    .tint(.orange)
                }
            }
        }
    }

    private var readinessSubtitle: String {
        switch readiness.level {
        case .ready:
            return "当前会话等待你的输入"
        case .blocked:
            return "应用部分功能受限，需要你授权"
        case .noSession:
            return "还没有活跃的 Claude Code 会话"
        case .limitedReply:
            return "当前会话暂时无法回复"
        case .partialObservation:
            return "检测到非 Claude 会话，需要确认 Claude Code 已启动"
        }
    }

    private var readinessTitleColor: Color {
        switch readiness.level {
        case .ready:
            return .green
        case .blocked, .limitedReply:
            return .orange
        case .noSession, .partialObservation:
            return .white
        }
    }

    private func openAutomationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
            NSWorkspace.shared.open(url)
        }
    }
}

private struct DiagnosticsDisclosureView: View {
    @Binding var isExpanded: Bool
    let session: TaskSession?
    let capabilityStatus: CapabilityStatus
    let observationDiagnostics: ObservationDiagnostics
    let traySessionCount: Int
    let isTrayEligible: Bool
    let preferredIslandSessionStatus: TaskStatus?

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            DiagnosticsSectionView(
                session: session,
                capabilityStatus: capabilityStatus,
                observationDiagnostics: observationDiagnostics,
                traySessionCount: traySessionCount,
                isTrayEligible: isTrayEligible,
                preferredIslandSessionStatus: preferredIslandSessionStatus
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
