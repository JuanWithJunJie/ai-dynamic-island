import AppKit
import SwiftUI
import MacIrlandKit
import Observation

@MainActor
final class IslandCoordinator {
    private let window: NSPanel
    private let store: TaskStateStore
    private let action: () -> Void
    private var mode: IslandSurfaceMode = .compact
    private var dismissedHighlightedSessionID: TaskSession.ID?
    private var actionResult: ReplyValidationResult?

    init(store: TaskStateStore, action: @escaping () -> Void) {
        self.store = store
        self.action = action

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 44),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .statusBar
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.ignoresMouseEvents = false

        self.window = panel
        recomputeMode()
        layoutWindow()
        panel.orderFrontRegardless()
        observeStore()
    }

    func layoutWindow() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let visibleFrame = screen.visibleFrame
        let size = window.frame.size
        let origin = NSPoint(
            x: visibleFrame.midX - (size.width / 2),
            y: visibleFrame.maxY - size.height - 6
        )
        window.setFrameOrigin(origin)
    }

    private func recomputeMode() {
        if case let .highlighted(presentation) = mode,
           store.topSession?.id != presentation.sessionID {
            actionResult = nil
        }

        if let topSession = store.topSession,
           topSession.id != dismissedHighlightedSessionID,
           let highlighted = HighlightedIslandPresentation(topSession: topSession) {
            mode = .highlighted(highlighted)
            window.setContentSize(CGSize(width: 860, height: 152))
        } else {
            mode = .compact
            window.setContentSize(CGSize(width: 520, height: 44))
        }

        window.contentView = NSHostingView(
            rootView: IslandSurfaceView(
                store: store,
                mode: mode,
                actionResult: actionResult,
                openPanel: { [weak self] in self?.openPanel() },
                triggerPrimaryAction: { [weak self] in self?.triggerPrimaryAction() },
                dismissHighlight: { [weak self] in self?.dismissHighlight() }
            )
        )
        layoutWindow()
    }

    private func dismissHighlight() {
        actionResult = nil
        if case let .highlighted(presentation) = mode {
            dismissedHighlightedSessionID = presentation.sessionID
        }
        recomputeMode()
    }

    private func triggerPrimaryAction() {
        guard case let .highlighted(presentation) = mode,
              let topSession = store.topSession,
              topSession.id == presentation.sessionID,
              let action = presentation.primaryAction else {
            return
        }

        actionResult = store.performQuickAction(action, for: topSession)
        recomputeMode()
    }

    private func openPanel() {
        action()
        dismissedHighlightedSessionID = nil
        recomputeMode()
    }

    private func observeStore() {
        withObservationTracking { [weak self] in
            guard let self else { return }
            _ = store.summary
            _ = store.topSession
        } onChange: { [weak self] in
            DispatchQueue.main.async {
                guard let self else { return }
                self.recomputeMode()
                self.observeStore()
            }
        }
    }
}
