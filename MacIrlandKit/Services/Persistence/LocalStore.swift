import Foundation

public protocol LocalStoring: Sendable {
    func save(soundMode: SoundMode)
    func loadSoundMode() -> SoundMode
    func save(observationMode: ObservationMode)
    func loadObservationMode() -> ObservationMode
    func save(autoRefreshInterval: TimeInterval)
    func loadAutoRefreshInterval() -> TimeInterval
}

public final class InMemoryLocalStore: LocalStoring, @unchecked Sendable {
    private var storedMode: SoundMode
    private var storedObservationMode: ObservationMode
    private var storedAutoRefreshInterval: TimeInterval

    public init(
        initialMode: SoundMode = .criticalOnly,
        initialObservationMode: ObservationMode = .timeline,
        initialAutoRefreshInterval: TimeInterval = 4
    ) {
        self.storedMode = initialMode
        self.storedObservationMode = initialObservationMode
        self.storedAutoRefreshInterval = initialAutoRefreshInterval
    }

    public func save(soundMode: SoundMode) {
        storedMode = soundMode
    }

    public func loadSoundMode() -> SoundMode {
        storedMode
    }

    public func save(observationMode: ObservationMode) {
        storedObservationMode = observationMode
    }

    public func loadObservationMode() -> ObservationMode {
        storedObservationMode
    }

    public func save(autoRefreshInterval: TimeInterval) {
        storedAutoRefreshInterval = autoRefreshInterval
    }

    public func loadAutoRefreshInterval() -> TimeInterval {
        storedAutoRefreshInterval
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
