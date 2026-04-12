import AppKit
import SwiftUI
import MacIrlandKit
import Observation

@MainActor
final class IslandCoordinator {
    private let window: NSPanel
    private let store: TaskStateStore
    private var mode: IslandSurfaceMode = .compact
    private var actionResult: ReplyValidationResult?
    private var autoCollapseWorkItem: DispatchWorkItem?
    private var hoverWorkItem: DispatchWorkItem?
    private var globalMouseMonitor: Any?
    private var hoverTimer: Timer?
    private var isHovering = false

    private final class MouseTrackingView: NSView {
        weak var coordinator: IslandCoordinator?

        override func mouseEntered(with event: NSEvent) {
            coordinator?.handleMouseEntered()
        }

        override func mouseExited(with event: NSEvent) {
            coordinator?.handleMouseExited()
        }
    }

    init(store: TaskStateStore) {
        self.store = store

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 44),
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
        setupHoverTracking()
        startHoverPolling()
        observeStore()
    }

    private let topAnchorInset: CGFloat = 1

    func layoutWindow() {
        layoutWindow(with: window.frame.size)
    }

    func layoutWindow(with size: CGSize) {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let screenFrame = screen.frame
        let origin = NSPoint(
            x: screenFrame.midX - (size.width / 2),
            y: screenFrame.maxY - size.height - topAnchorInset
        )
        window.setFrame(NSRect(origin: origin, size: size), display: true)
    }

    private func recomputeMode() {
        // Priority 1: If hovering and at least one session, show hoverExpand
        if isHovering && !store.sessions.isEmpty {
            mode = .hoverExpand
            cancelAutoCollapse()
            let newSize = CGSize(width: 520, height: hoverExpandHeight)
            window.setContentSize(newSize)
            window.layoutIfNeeded()
            window.contentView = NSHostingView(
                rootView: IslandSurfaceView(
                    store: store,
                    mode: mode,
                    actionResult: nil,
                    openPanel: { [weak self] in self?.openPanel() },
                    openPanelForSession: { [weak self] sessionID in
                        self?.openPanelForSession(sessionID)
                    },
                    onTrayHoverChanged: { [weak self] hovering in
                        self?.handleTrayHoverChanged(hovering)
                    },
                    jumpToSession: { [weak self] sessionID in
                        self?.jumpToSession(sessionID)
                    },
                    onHoverExpandHoverChanged: { [weak self] hovering in
                        self?.handleHoverExpandHoverChanged(hovering)
                    },
                    onHoverExpandContinue: { [weak self] in
                        self?.triggerHoverExpandContinue()
                    }
                )
            )
            layoutWindow(with: newSize)
            return
        }

        // Always fall through to compact mode
        mode = .compact
        window.setContentSize(CGSize(width: 300, height: 44))
        cancelAutoCollapse()

        window.contentView = NSHostingView(
            rootView: IslandSurfaceView(
                store: store,
                mode: mode,
                actionResult: actionResult,
                openPanel: { [weak self] in self?.openPanel() }
            )
        )
        let compactSize = CGSize(width: 300, height: 44)
        layoutWindow(with: compactSize)
    }

    private var compactTrayHeight: CGFloat {
        let headerHeight: CGFloat = 34
        let rowHeight: CGFloat = 44
        let visibleRows = min(store.sessions.count, 5)
        return headerHeight + CGFloat(visibleRows) * rowHeight + 16
    }

    private var hoverExpandHeight: CGFloat {
        // Status strip + primary detail + optional secondary rows
        let statusStripHeight: CGFloat = 36
        let detailSectionHeight: CGFloat = store.hoverExpandPrimarySession == nil ? 0 : 120
        let listHeaderHeight: CGFloat = store.hoverExpandSecondarySessions.isEmpty ? 0 : 32
        let rowHeight: CGFloat = 44
        let visibleRows = min(store.hoverExpandSecondarySessions.count, 3)
        let padding: CGFloat = 16
        return statusStripHeight + detailSectionHeight + listHeaderHeight + CGFloat(visibleRows) * rowHeight + padding
    }

    private func setupHoverTracking() {
        guard let contentView = window.contentView else { return }
        // Remove any existing tracking views first
        contentView.subviews.compactMap { $0 as? MouseTrackingView }.forEach { $0.removeFromSuperview() }
        let trackingView = MouseTrackingView()
        trackingView.coordinator = self
        trackingView.frame = contentView.bounds
        trackingView.autoresizingMask = [.width, .height]
        contentView.addSubview(trackingView)
        trackingView.addTrackingArea(NSTrackingArea(
            rect: trackingView.bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: trackingView,
            userInfo: nil
        ))
    }

    private func startHoverPolling() {
        // Use 50ms timer polling for hover detection as primary mechanism
        // (.nonactivatingPanel + NSTrackingArea can miss events on some macOS versions)
        hoverTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.checkHoverState()
            }
        }

        // Global event monitor for mouse moved events as supplement
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.checkHoverState()
            }
        }
    }

    private func checkHoverState() {
        let mouseLocation = NSEvent.mouseLocation
        let windowFrame = window.frame
        let isOverWindow = windowFrame.contains(mouseLocation)

        if isOverWindow && !isHovering {
            isHovering = true
            handleMouseEntered()
        } else if !isOverWindow && isHovering {
            isHovering = false
            handleMouseExited()
        }
    }

    private func handleMouseEntered() {
        print("IslandCoordinator: handleMouseEntered")
        // Allow entering hoverExpand from any mode except hoverExpand itself
        guard mode != .hoverExpand else { return }
        // Require at least one Claude-first hover session so the hover layer matches
        // the compact count and the detail/list split remains consistent.
        guard !store.hoverExpandSessions.isEmpty else { return }

        cancelHoverTimer()
        isHovering = true

        // Small dwell delay before showing hoverExpand (200ms)
        let workItem = DispatchWorkItem { [weak self] in
            guard let self, self.isHovering else { return }
            self.mode = .hoverExpand
            self.recomputeMode()
        }
        hoverWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: workItem)
    }

    private func handleMouseExited() {
        print("IslandCoordinator: handleMouseExited")
        isHovering = false
        cancelHoverTimer()
        guard case .hoverExpand = mode else { return }
        mode = .compact
        recomputeMode()
    }

    private func handleTrayHoverChanged(_ hovering: Bool) {
        print("IslandCoordinator: handleTrayHoverChanged hovering=\(hovering)")
        isHovering = hovering
        if !hovering {
            cancelHoverTimer()
            guard case .hoverExpand = mode else { return }
            // Use a delay before collapsing to allow mouse movement within hover expand
            // Increased from 150ms to 300ms to prevent accidental collapse when
            // mouse briefly exits during subview navigation (e.g., moving between
            // the detail section and the session list)
            let workItem = DispatchWorkItem { [weak self] in
                guard let self else { return }
                guard case .hoverExpand = self.mode else { return }
                self.mode = .compact
                self.recomputeMode()
            }
            autoCollapseWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: workItem)
        } else {
            // Mouse re-entered - cancel any pending collapse
            cancelAutoCollapse()
        }
    }

    private func handleHoverExpandHoverChanged(_ hovering: Bool) {
        print("IslandCoordinator: handleHoverExpandHoverChanged hovering=\(hovering)")
        isHovering = hovering
        if !hovering {
            cancelHoverTimer()
            guard case .hoverExpand = mode else { return }
            // Use a delay before collapsing to allow mouse movement within hover expand
            // Without this, moving the mouse slightly (e.g., to click a session row)
            // can trigger hover exit and collapse before the click registers
            // Increased from 150ms to 300ms to prevent accidental collapse
            let workItem = DispatchWorkItem { [weak self] in
                guard let self else { return }
                guard case .hoverExpand = self.mode else { return }
                self.mode = .compact
                self.recomputeMode()
            }
            autoCollapseWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: workItem)
        } else {
            // Mouse re-entered - cancel any pending collapse
            cancelAutoCollapse()
        }
    }

    private func cancelHoverTimer() {
        hoverWorkItem?.cancel()
        hoverWorkItem = nil
    }

    private func cancelAutoCollapse() {
        autoCollapseWorkItem?.cancel()
        autoCollapseWorkItem = nil
    }

    private func triggerHoverExpandContinue() {
        cancelAutoCollapse()
        guard let session = store.hoverExpandPrimarySession,
              let action = session.quickActions.first else {
            return
        }

        actionResult = store.performQuickAction(action, for: session)
        recomputeMode()
    }

    private func openPanel() {
        // Panel display disabled - only do local cleanup
        cancelAutoCollapse()
        cancelHoverTimer()
        mode = .compact
        recomputeMode()
    }

    private func openPanelForSession(_ sessionID: TaskSession.ID) {
        // Panel display disabled - only do local cleanup and jump to session
        cancelAutoCollapse()
        cancelHoverTimer()
        jumpToSession(sessionID)
        mode = .compact
        recomputeMode()
    }

    private func jumpToSession(_ sessionID: TaskSession.ID) {
        let ids = store.sessions.map { $0.id }
        let logLine = "IslandCoordinator: jumpToSession id=\(sessionID) availableIDs=\(ids)\n"
        if let data = logLine.data(using: .utf8) {
            try? data.write(to: URL(fileURLWithPath: "/tmp/macirland-jump.log"))
        }
        guard let session = store.sessions.first(where: { $0.id == sessionID }) else {
            if let data = "IslandCoordinator: Session not found\n".data(using: .utf8) {
                try? data.write(to: URL(fileURLWithPath: "/tmp/macirland-jump.log"))
            }
            return
        }
        let info = "IslandCoordinator: Found session tty=\(session.identity.ttyIdentifier ?? "nil") window=\(session.identity.windowIdentifier) cmdLine=\(session.identity.commandLine)\n"
        if let data = info.data(using: .utf8) {
            try? data.write(to: URL(fileURLWithPath: "/tmp/macirland-jump.log"))
        }
        TerminalJumpService.jump(to: session)
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
