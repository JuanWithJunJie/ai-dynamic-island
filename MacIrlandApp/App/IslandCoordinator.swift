import AppKit
import SwiftUI
import MacIrlandKit
import Observation

@MainActor
final class IslandCoordinator {
    private let window: NSPanel
    private let store: TaskStateStore
    private let action: (TaskSession.ID?) -> Void
    private var mode: IslandSurfaceMode = .compact
    private var dismissedHighlightedSessionID: TaskSession.ID?
    private var activeHighlightedSessionID: TaskSession.ID?
    private var actionResult: ReplyValidationResult?
    private var autoCollapseWorkItem: DispatchWorkItem?

    init(store: TaskStateStore, action: @escaping (TaskSession.ID?) -> Void) {
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

    private let topAnchorInset: CGFloat = 1

    func layoutWindow() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let screenFrame = screen.frame
        let size = window.frame.size
        let origin = NSPoint(
            x: screenFrame.midX - (size.width / 2),
            y: screenFrame.maxY - size.height - topAnchorInset
        )
        window.setFrameOrigin(origin)
    }

    private func recomputeMode() {
        if case let .highlighted(presentation) = mode,
           store.topSession?.id != presentation.sessionID {
            actionResult = nil
        }

        if let highlightedSession = arbitrationTarget(),
           highlightedSession.id != dismissedHighlightedSessionID {
            let queueCount = store.secondaryIslandAttentionCount(excluding: highlightedSession.id)
            guard let highlighted = HighlightedIslandPresentation(topSession: highlightedSession, queueCount: queueCount) else {
                activeHighlightedSessionID = nil
                mode = .compact
                window.setContentSize(CGSize(width: 520, height: 44))
                cancelAutoCollapse()
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
                return
            }
            activeHighlightedSessionID = highlightedSession.id
            mode = .highlighted(highlighted)
            window.setContentSize(CGSize(width: 860, height: 152))
            scheduleAutoCollapseIfNeeded(for: highlighted)
        } else {
            activeHighlightedSessionID = nil
            mode = .compact
            window.setContentSize(CGSize(width: 520, height: 44))
            cancelAutoCollapse()
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

    private func arbitrationTarget() -> TaskSession? {
        let attentionQueue = store.islandAttentionSessions.filter { $0.id != dismissedHighlightedSessionID }

        guard let topCandidate = attentionQueue.first else {
            return nil
        }

        if let currentActiveID = activeHighlightedSessionID,
           let currentActive = attentionQueue.first(where: { $0.id == currentActiveID }) {
            let currentTier = TaskStatus.tier(for: currentActive.status)
            let candidateTier = TaskStatus.tier(for: topCandidate.status)
            if currentTier >= candidateTier {
                return currentActive
            }
        }

        return topCandidate
    }

    private func cancelAutoCollapse() {
        autoCollapseWorkItem?.cancel()
        autoCollapseWorkItem = nil
    }

    private func scheduleAutoCollapseIfNeeded(for presentation: HighlightedIslandPresentation) {
        cancelAutoCollapse()

        guard let delay = presentation.autoCollapseDelay else {
            return
        }

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.dismissedHighlightedSessionID = presentation.sessionID
            self.actionResult = nil
            self.activeHighlightedSessionID = nil
            self.recomputeMode()
        }

        autoCollapseWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func dismissHighlight() {
        cancelAutoCollapse()
        actionResult = nil
        if case let .highlighted(presentation) = mode {
            dismissedHighlightedSessionID = presentation.sessionID
        }
        activeHighlightedSessionID = nil
        recomputeMode()
    }

    private func triggerPrimaryAction() {
        cancelAutoCollapse()
        guard case let .highlighted(presentation) = mode,
              let currentActiveID = activeHighlightedSessionID,
              currentActiveID == presentation.sessionID,
              let session = store.sessions.first(where: { $0.id == currentActiveID }),
              let action = presentation.primaryAction else {
            return
        }

        actionResult = store.performQuickAction(action, for: session)
        recomputeMode()
    }

    private func openPanel() {
        cancelAutoCollapse()
        let sessionIDToFocus: TaskSession.ID?
        if case .highlighted = mode {
            sessionIDToFocus = activeHighlightedSessionID
        } else {
            sessionIDToFocus = store.preferredIslandSession?.id ?? store.topSession?.id
        }
        action(sessionIDToFocus)
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
