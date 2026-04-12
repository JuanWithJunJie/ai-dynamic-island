import SwiftUI

public enum IslandSurfaceMode: Equatable {
    case compact
    case tray
    case hoverExpand
}

public struct IslandSurfaceView: View {
    @Bindable var store: TaskStateStore
    let mode: IslandSurfaceMode
    let actionResult: ReplyValidationResult?
    let openPanel: () -> Void
    let openPanelForSession: ((TaskSession.ID) -> Void)?
    let onTrayHoverChanged: ((Bool) -> Void)?
    let jumpToSession: ((TaskSession.ID) -> Void)?
    let onHoverExpandHoverChanged: ((Bool) -> Void)?
    let onHoverExpandContinue: (() -> Void)?

    public init(
        store: TaskStateStore,
        mode: IslandSurfaceMode,
        actionResult: ReplyValidationResult?,
        openPanel: @escaping () -> Void,
        openPanelForSession: ((TaskSession.ID) -> Void)? = nil,
        onTrayHoverChanged: ((Bool) -> Void)? = nil,
        jumpToSession: ((TaskSession.ID) -> Void)? = nil,
        onHoverExpandHoverChanged: ((Bool) -> Void)? = nil,
        onHoverExpandContinue: (() -> Void)? = nil
    ) {
        self.store = store
        self.mode = mode
        self.actionResult = actionResult
        self.openPanel = openPanel
        self.openPanelForSession = openPanelForSession
        self.onTrayHoverChanged = onTrayHoverChanged
        self.jumpToSession = jumpToSession
        self.onHoverExpandHoverChanged = onHoverExpandHoverChanged
        self.onHoverExpandContinue = onHoverExpandContinue
    }

    public var body: some View {
        Group {
            switch mode {
            case .compact:
                IslandStatusStripView(store: store, action: openPanel)
            case .tray:
                IslandMultiSessionTrayView(
                    store: store,
                    onSessionSelected: { sessionID in
                        openPanelForSession?(sessionID)
                    },
                    onHoverChanged: { isHovering in
                        onTrayHoverChanged?(isHovering)
                    }
                )
            case .hoverExpand:
                IslandHoverExpandView(
                    store: store,
                    preferredSessionID: store.hoverExpandPrimarySession?.id,
                    onJumpToSession: { sessionID in
                        jumpToSession?(sessionID)
                    },
                    onHoverChanged: { isHovering in
                        onHoverExpandHoverChanged?(isHovering)
                    },
                    onContinueAction: {
                        onHoverExpandContinue?()
                    }
                )
            }
        }
        .animation(.spring(response: 0.34, dampingFraction: 0.86), value: mode)
    }
}
