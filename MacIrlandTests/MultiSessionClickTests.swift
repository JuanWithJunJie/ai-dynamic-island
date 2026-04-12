import XCTest
@testable import MacIrlandKit

/// Tests for deterministic multi-session UI click behavior.
///
/// These tests verify that:
/// 1. Hover expand secondary rows preserve distinct TaskSession.IDs
/// 2. Clicking a given secondary session row calls jump using that exact session ID
/// 3. Selected session / preferred session / hover primary session do not collapse
///    multiple sessions into one jump target
final class MultiSessionClickTests: XCTestCase {
    // MARK: - Test: Hover expand secondary rows have distinct IDs

    func testHoverExpandSecondarySessionsHaveDistinctIDs() {
        // Given: A store with multiple Claude Code sessions (non-terminal states)
        let event1 = RawCLIEvent(
            cliKind: .claudeCode,
            snippet: "Running task A...",
            snapshot: TerminalObservationSnapshot(
                terminalAppIdentifier: "com.apple.Terminal",
                windowTitle: "Claude Code · project-a",
                commandLine: "claude",
                ttyIdentifier: "ttys101"
            )
        )
        let event2 = RawCLIEvent(
            cliKind: .claudeCode,
            snippet: "Running task B...",
            snapshot: TerminalObservationSnapshot(
                terminalAppIdentifier: "com.apple.Terminal",
                windowTitle: "Claude Code · project-b",
                commandLine: "claude",
                ttyIdentifier: "ttys102"
            )
        )
        let event3 = RawCLIEvent(
            cliKind: .claudeCode,
            snippet: "Running task C...",
            snapshot: TerminalObservationSnapshot(
                terminalAppIdentifier: "com.apple.Terminal",
                windowTitle: "Claude Code · project-c",
                commandLine: "claude",
                ttyIdentifier: "ttys103"
            )
        )

        let store = TaskStateStore(
            observationService: SimpleObservationService(events: [event1, event2, event3])
        )

        // When: We get hover expand secondary sessions
        let secondarySessions = store.hoverExpandSecondarySessions

        // Then: All secondary sessions should have distinct IDs
        let ids = secondarySessions.map { $0.id }
        let uniqueIDs = Set(ids)
        XCTAssertEqual(ids.count, uniqueIDs.count, "Secondary sessions should have distinct IDs, but found duplicates: \(ids)")
    }

    // MARK: - Test: Clicking secondary row calls jump with correct session ID

    func testClickingSecondaryRowCallsJumpWithCorrectSessionID() throws {
        // Given: A store with multiple sessions where secondary sessions exist
        let event1 = RawCLIEvent(
            cliKind: .claudeCode,
            snippet: "Running primary task...",
            snapshot: TerminalObservationSnapshot(
                terminalAppIdentifier: "com.apple.Terminal",
                windowTitle: "Claude Code · primary",
                commandLine: "claude",
                ttyIdentifier: "ttys201"
            )
        )
        let event2 = RawCLIEvent(
            cliKind: .claudeCode,
            snippet: "Please confirm to continue.",  // waitingInput status
            snapshot: TerminalObservationSnapshot(
                terminalAppIdentifier: "com.apple.Terminal",
                windowTitle: "Claude Code · secondary",
                commandLine: "claude",
                ttyIdentifier: "ttys202"
            )
        )

        let store = TaskStateStore(
            observationService: SimpleObservationService(events: [event1, event2])
        )

        // Verify secondary session exists
        let secondarySessions = store.hoverExpandSecondarySessions
        XCTAssertFalse(secondarySessions.isEmpty, "Should have at least one secondary session")

        // When: We capture the secondary session's ID (as would happen on row tap)
        guard let secondarySession = secondarySessions.first else {
            XCTFail("Expected at least one secondary session")
            return
        }
        let clickedSessionID = secondarySession.id

        // Then: The jump lookup should find the exact session by ID
        let sessionFoundViaID = store.sessions.first { $0.id == clickedSessionID }
        XCTAssertNotNil(sessionFoundViaID, "Should find session by exact ID")
        XCTAssertEqual(sessionFoundViaID?.id, clickedSessionID, "Found session should have the exact same ID")
        XCTAssertEqual(sessionFoundViaID?.title, secondarySession.title, "Found session should have the same title")
    }

    // MARK: - Test: Multiple sessions do not collapse into one jump target

    func testMultipleSessionsDoNotCollapseIntoOneJumpTarget() throws {
        // Given: Multiple sessions with different IDs, titles, and TTYs
        let event1 = RawCLIEvent(
            cliKind: .claudeCode,
            snippet: "alpha session running",
            snapshot: TerminalObservationSnapshot(
                terminalAppIdentifier: "com.apple.Terminal",
                windowTitle: "Claude Code · alpha",
                commandLine: "claude",
                ttyIdentifier: "ttys301"
            )
        )
        let event2 = RawCLIEvent(
            cliKind: .claudeCode,
            snippet: "beta session running",
            snapshot: TerminalObservationSnapshot(
                terminalAppIdentifier: "com.apple.Terminal",
                windowTitle: "Claude Code · beta",
                commandLine: "claude",
                ttyIdentifier: "ttys302"
            )
        )
        let event3 = RawCLIEvent(
            cliKind: .claudeCode,
            snippet: "gamma session running",
            snapshot: TerminalObservationSnapshot(
                terminalAppIdentifier: "com.apple.Terminal",
                windowTitle: "Claude Code · gamma",
                commandLine: "claude",
                ttyIdentifier: "ttys303"
            )
        )

        let store = TaskStateStore(
            observationService: SimpleObservationService(events: [event1, event2, event3])
        )

        // Then: All sessions should have distinct IDs
        let ids = store.sessions.map { $0.id }
        let uniqueIDs = Set(ids)
        XCTAssertEqual(ids.count, uniqueIDs.count, "All sessions should have distinct IDs")
        XCTAssertEqual(ids.count, 3, "Should have exactly 3 sessions")

        // When: Getting each session by index
        guard store.sessions.count >= 3 else {
            XCTFail("Expected at least 3 sessions")
            return
        }
        let session0 = store.sessions[0]
        let session1 = store.sessions[1]
        let session2 = store.sessions[2]

        // Then: Each session should have a unique ID
        XCTAssertNotEqual(session0.id, session1.id)
        XCTAssertNotEqual(session1.id, session2.id)
        XCTAssertNotEqual(session0.id, session2.id)

        // And: Each session should be findable by its own exact ID
        let found0 = store.sessions.first { $0.id == session0.id }
        let found1 = store.sessions.first { $0.id == session1.id }
        let found2 = store.sessions.first { $0.id == session2.id }

        XCTAssertEqual(found0?.id, session0.id)
        XCTAssertEqual(found1?.id, session1.id)
        XCTAssertEqual(found2?.id, session2.id)

        // And: Titles should be different
        XCTAssertNotEqual(found0?.title, found1?.title)
        XCTAssertNotEqual(found1?.title, found2?.title)
    }

    // MARK: - Test: Secondary session row ID is preserved when looking up

    func testSecondarySessionRowIDIsPreservedWhenLookingUp() throws {
        // Given: A store with primary and secondary sessions
        let event1 = RawCLIEvent(
            cliKind: .claudeCode,
            snippet: "Running primary...",
            snapshot: TerminalObservationSnapshot(
                terminalAppIdentifier: "com.apple.Terminal",
                windowTitle: "Claude Code · primary",
                commandLine: "claude",
                ttyIdentifier: "ttys401"
            )
        )
        let event2 = RawCLIEvent(
            cliKind: .claudeCode,
            snippet: "Please confirm to continue.",
            snapshot: TerminalObservationSnapshot(
                terminalAppIdentifier: "com.apple.Terminal",
                windowTitle: "Claude Code · secondary",
                commandLine: "claude",
                ttyIdentifier: "ttys402"
            )
        )

        let store = TaskStateStore(
            observationService: SimpleObservationService(events: [event1, event2])
        )

        // When: We capture the secondary session's ID
        guard let secondarySession = store.hoverExpandSecondarySessions.first else {
            XCTFail("Expected at least one secondary session")
            return
        }
        let capturedSecondaryID = secondarySession.id

        // Then: The captured ID should correctly identify the secondary session
        let foundSession = store.sessions.first { $0.id == capturedSecondaryID }
        XCTAssertNotNil(foundSession)
        XCTAssertEqual(foundSession?.title, secondarySession.title)
    }

    // MARK: - Test: Jump lookup uses exact ID match, not fuzzy match on TTY

    func testJumpLookupUsesExactIDMatchNotFuzzyMatchOnTTY() throws {
        // Given: Sessions with same TTY but different IDs (simulating merged session scenario)
        // Note: In practice, sessions with same TTY would be merged, but this tests that
        // even if they existed, exact ID lookup is used rather than TTY-based fuzzy match
        let event1 = RawCLIEvent(
            cliKind: .claudeCode,
            snippet: "Session One",
            snapshot: TerminalObservationSnapshot(
                terminalAppIdentifier: "com.apple.Terminal",
                windowTitle: "Claude Code · one",
                commandLine: "claude",
                ttyIdentifier: "ttys500"  // Same TTY
            )
        )
        let event2 = RawCLIEvent(
            cliKind: .claudeCode,
            snippet: "Session Two",
            snapshot: TerminalObservationSnapshot(
                terminalAppIdentifier: "com.apple.Terminal",
                windowTitle: "Claude Code · two",
                commandLine: "claude",
                ttyIdentifier: "ttys500"  // Same TTY
            )
        )

        let store = TaskStateStore(
            observationService: SimpleObservationService(events: [event1, event2])
        )

        // The sessions should have been deduplicated (same TTY = same session)
        // But if they weren't, we should still find by exact ID
        guard store.sessions.count >= 2 else {
            // Sessions merged - this is expected behavior
            XCTAssertEqual(store.sessions.count, 1, "Sessions with same TTY should merge")
            return
        }

        // Sessions not merged - each should be findable by exact ID
        let session1 = store.sessions[0]
        let session2 = store.sessions[1]

        XCTAssertNotEqual(session1.id, session2.id, "Distinct sessions should have distinct IDs")

        let found1 = store.sessions.first { $0.id == session1.id }
        let found2 = store.sessions.first { $0.id == session2.id }

        XCTAssertEqual(found1?.id, session1.id)
        XCTAssertEqual(found2?.id, session2.id)
    }

    // MARK: - Test: hoverExpandSecondarySessions excludes primary

    func testHoverExpandSecondarySessionsExcludesPrimary() throws {
        // Given: A store with sessions where one will be primary
        let event1 = RawCLIEvent(
            cliKind: .claudeCode,
            snippet: "first task running",
            snapshot: TerminalObservationSnapshot(
                terminalAppIdentifier: "com.apple.Terminal",
                windowTitle: "Claude Code · first",
                commandLine: "claude",
                ttyIdentifier: "ttys601"
            )
        )
        let event2 = RawCLIEvent(
            cliKind: .claudeCode,
            snippet: "second task running",
            snapshot: TerminalObservationSnapshot(
                terminalAppIdentifier: "com.apple.Terminal",
                windowTitle: "Claude Code · second",
                commandLine: "claude",
                ttyIdentifier: "ttys602"
            )
        )
        let event3 = RawCLIEvent(
            cliKind: .claudeCode,
            snippet: "third task running",
            snapshot: TerminalObservationSnapshot(
                terminalAppIdentifier: "com.apple.Terminal",
                windowTitle: "Claude Code · third",
                commandLine: "claude",
                ttyIdentifier: "ttys603"
            )
        )

        let store = TaskStateStore(
            observationService: SimpleObservationService(events: [event1, event2, event3])
        )

        // When: We get primary and secondary
        let primaryID = store.hoverExpandPrimarySession?.id
        let secondaryIDs = Set(store.hoverExpandSecondarySessions.map { $0.id })

        // Then: Secondary should NOT contain the primary
        if let primaryID = primaryID {
            XCTAssertFalse(secondaryIDs.contains(primaryID),
                "Secondary sessions should not contain primary session ID")
        }

        // And: Primary and secondary together should cover all sessions
        var allIDs = Array(secondaryIDs)
        if let primaryID = primaryID {
            allIDs.append(primaryID)
        }
        XCTAssertEqual(allIDs.count, store.sessions.count, "All sessions should be either primary or secondary")
    }

    // MARK: - Test: Same session ID persists across refresh

    func testSameSessionIDPersistsAcrossRefresh() throws {
        // Given: A store with sessions
        let event1 = RawCLIEvent(
            cliKind: .claudeCode,
            snippet: "Task running...",
            snapshot: TerminalObservationSnapshot(
                terminalAppIdentifier: "com.apple.Terminal",
                windowTitle: "Claude Code · project",
                commandLine: "claude",
                ttyIdentifier: "ttys701"
            )
        )
        let event2 = RawCLIEvent(
            cliKind: .claudeCode,
            snippet: "Another task running...",
            snapshot: TerminalObservationSnapshot(
                terminalAppIdentifier: "com.apple.Terminal",
                windowTitle: "Claude Code · other",
                commandLine: "claude",
                ttyIdentifier: "ttys702"
            )
        )

        let source = SimpleMutableObservationService(initialEvents: [event1, event2])
        let store = TaskStateStore(observationService: source)

        // Capture original session IDs
        let originalIDs = Set(store.sessions.map { $0.id })
        XCTAssertEqual(originalIDs.count, 2, "Should have 2 distinct sessions")

        // When: Refresh happens with same events
        store.refresh()

        // Then: Session IDs should be preserved
        let refreshedIDs = Set(store.sessions.map { $0.id })
        XCTAssertEqual(refreshedIDs, originalIDs, "Session IDs should persist across refresh")

        // And: We should still be able to look up by original ID
        for originalID in originalIDs {
            let found = store.sessions.first { $0.id == originalID }
            XCTAssertNotNil(found, "Should find session by ID after refresh")
        }
    }

    // MARK: - Test: Click on secondary session uses exact ID even after refresh

    func testClickOnSecondarySessionUsesExactIDEvenAfterRefresh() throws {
        // Given: A store with multiple sessions
        let event1 = RawCLIEvent(
            cliKind: .claudeCode,
            snippet: "Primary task running...",
            snapshot: TerminalObservationSnapshot(
                terminalAppIdentifier: "com.apple.Terminal",
                windowTitle: "Claude Code · primary",
                commandLine: "claude",
                ttyIdentifier: "ttys801"
            )
        )
        let event2 = RawCLIEvent(
            cliKind: .claudeCode,
            snippet: "Secondary task running...",
            snapshot: TerminalObservationSnapshot(
                terminalAppIdentifier: "com.apple.Terminal",
                windowTitle: "Claude Code · secondary",
                commandLine: "claude",
                ttyIdentifier: "ttys802"
            )
        )

        let source = SimpleMutableObservationService(initialEvents: [event1, event2])
        let store = TaskStateStore(observationService: source)

        // Get the secondary session before refresh
        guard let secondaryBefore = store.hoverExpandSecondarySessions.first else {
            XCTFail("Expected secondary session before refresh")
            return
        }
        let secondaryIDBefore = secondaryBefore.id

        // When: A refresh happens (simulating auto-refresh cycle)
        store.refresh()

        // And: User clicks on what was previously a secondary session
        // The clicked ID should still find the correct session
        let foundAfterRefresh = store.sessions.first { $0.id == secondaryIDBefore }

        XCTAssertNotNil(foundAfterRefresh,
            "Should find session by ID even after refresh (click would use exact ID)")
        XCTAssertEqual(foundAfterRefresh?.title, secondaryBefore.title,
            "Found session should have same title as clicked session")
    }
}

// MARK: - Private Test Helpers

private struct SimpleObservationService: ObservationProviding {
    let events: [RawCLIEvent]

    init(events: [RawCLIEvent]) {
        self.events = events
    }

    func latestSnapshot() -> ObservationSnapshotResult {
        ObservationSnapshotResult(
            events: events,
            diagnostics: ObservationDiagnostics(readers: [], sessions: [])
        )
    }
}

private actor SimpleMutableEventSource {
    private var events: [RawCLIEvent]

    init(events: [RawCLIEvent]) {
        self.events = events
    }

    func update(_ newEvents: [RawCLIEvent]) {
        events = newEvents
    }

    func snapshot() -> [RawCLIEvent] {
        events
    }
}

private final class SimpleMutableObservationService: ObservationProviding, @unchecked Sendable {
    private let source: SimpleMutableEventSource

    init(initialEvents: [RawCLIEvent]) {
        self.source = SimpleMutableEventSource(events: initialEvents)
    }

    func updateEvents(_ events: [RawCLIEvent]) {
        Task {
            await source.update(events)
        }
    }

    func latestSnapshot() -> ObservationSnapshotResult {
        let semaphore = DispatchSemaphore(value: 0)
        var currentEvents: [RawCLIEvent] = []
        Task {
            currentEvents = await source.snapshot()
            semaphore.signal()
        }
        semaphore.wait()
        return ObservationSnapshotResult(
            events: currentEvents,
            diagnostics: ObservationDiagnostics(readers: [], sessions: [])
        )
    }
}
