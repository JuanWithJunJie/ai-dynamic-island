import Foundation

public protocol CLIAdapter: Sendable {
    var cliKind: CLIKind { get }
    var supportedQuickActions: [ReplyActionType] { get }
    var replyCapability: ReplyCapability { get }

    func recognizes(snapshot: TerminalObservationSnapshot) -> Bool
    func buildSession(from event: RawCLIEvent) -> TaskSession?
}

public struct AdapterRegistry: Sendable {
    public let adapters: [any CLIAdapter]

    public init(adapters: [any CLIAdapter]) {
        self.adapters = adapters
    }

    public func adapter(for snapshot: TerminalObservationSnapshot) -> (any CLIAdapter)? {
        adapters.first { $0.recognizes(snapshot: snapshot) }
    }
}
