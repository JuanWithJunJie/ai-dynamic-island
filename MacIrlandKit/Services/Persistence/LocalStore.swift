import Foundation

public protocol LocalStoring: Sendable {
    func save(soundMode: SoundMode)
    func loadSoundMode() -> SoundMode
}

public final class InMemoryLocalStore: LocalStoring, @unchecked Sendable {
    private var storedMode: SoundMode

    public init(initialMode: SoundMode = .criticalOnly) {
        self.storedMode = initialMode
    }

    public func save(soundMode: SoundMode) {
        storedMode = soundMode
    }

    public func loadSoundMode() -> SoundMode {
        storedMode
    }
}
