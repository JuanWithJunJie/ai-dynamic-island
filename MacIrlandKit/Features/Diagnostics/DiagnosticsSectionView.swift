import SwiftUI

public struct DiagnosticsSectionView: View {
    private let session: TaskSession?
    private let capabilityStatus: CapabilityStatus

    public init(session: TaskSession?, capabilityStatus: CapabilityStatus) {
        self.session = session
        self.capabilityStatus = capabilityStatus
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("诊断")
                .font(.headline)

            Text(capabilityStatus.explanation)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let session {
                VStack(alignment: .leading, spacing: 10) {
                    LabeledContent("当前状态") {
                        Text(session.status.label)
                    }
                    LabeledContent("置信度") {
                        Text("\(Int(session.confidence * 100))% · \(session.confidenceLevel.rawValue)")
                    }
                    LabeledContent("回复能力") {
                        Text(session.replyCapability.reason)
                    }

                    ForEach(session.evidence.prefix(3)) { evidence in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(evidence.summary)
                                .font(.subheadline.weight(.medium))
                            Text(evidence.rawSnippet)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            } else {
                Text("暂无可诊断的会话。")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
