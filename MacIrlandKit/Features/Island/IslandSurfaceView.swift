import SwiftUI

public enum IslandSurfaceMode: Equatable {
    case compact
    case highlighted(HighlightedIslandPresentation)
}

public struct IslandSurfaceView: View {
    @Bindable var store: TaskStateStore
    let mode: IslandSurfaceMode
    let actionResult: ReplyValidationResult?
    let openPanel: () -> Void
    let triggerPrimaryAction: () -> Void
    let dismissHighlight: () -> Void

    public init(
        store: TaskStateStore,
        mode: IslandSurfaceMode,
        actionResult: ReplyValidationResult?,
        openPanel: @escaping () -> Void,
        triggerPrimaryAction: @escaping () -> Void,
        dismissHighlight: @escaping () -> Void
    ) {
        self.store = store
        self.mode = mode
        self.actionResult = actionResult
        self.openPanel = openPanel
        self.triggerPrimaryAction = triggerPrimaryAction
        self.dismissHighlight = dismissHighlight
    }

    public var body: some View {
        switch mode {
        case .compact:
            IslandStatusStripView(store: store, action: openPanel)
        case .highlighted(let presentation):
            IslandExpandedCardView(
                presentation: presentation,
                actionResult: actionResult,
                openPanel: openPanel,
                triggerPrimaryAction: triggerPrimaryAction,
                dismiss: dismissHighlight
            )
        }
    }
}
