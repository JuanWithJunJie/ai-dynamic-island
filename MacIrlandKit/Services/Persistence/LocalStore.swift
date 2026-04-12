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

public final class UserDefaultsLocalStore: LocalStoring, @unchecked Sendable {
    private let defaults: UserDefaults
    private let soundModeKey = "MacIrland.SoundMode"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func save(soundMode: SoundMode) {
        defaults.set(soundMode.rawValue, forKey: soundModeKey)
    }

    public func loadSoundMode() -> SoundMode {
        guard let rawValue = defaults.string(forKey: soundModeKey),
              let mode = SoundMode(rawValue: rawValue) else {
            return .all
        }
        return mode
    }
}
