import SwiftUI
import MacIrlandKit

struct SettingsView: View {
    @Bindable var viewModel: TaskStateStore

    var body: some View {
        Form {
            Picker("声音提示", selection: soundModeBinding) {
                Text("全部开启").tag(SoundMode.all)
                Text("仅关键提示").tag(SoundMode.criticalOnly)
                Text("静音").tag(SoundMode.mute)
            }

            Button("刷新状态") {
                viewModel.refresh()
            }

            Text("当前共有 \(viewModel.sessions.count) 个会话，等待处理 \(viewModel.summary.waitingCount) 个。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(width: 360)
    }

    private var soundModeBinding: Binding<SoundMode> {
        Binding(
            get: { viewModel.soundMode },
            set: { viewModel.update(soundMode: $0) }
        )
    }
}
