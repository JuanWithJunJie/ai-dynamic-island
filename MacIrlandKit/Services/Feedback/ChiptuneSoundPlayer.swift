@preconcurrency import AVFoundation
import Foundation

public protocol SoundPlaying: Sendable {
    func play(_ cue: SoundCue)
    func playIfAllowed(_ cue: SoundCue, mode: SoundMode)
}

public final class ChiptuneSoundPlayer: SoundPlaying, @unchecked Sendable {
    private let audioEngine: AVAudioEngine
    private let mainMixer: AVAudioMixerNode
    private var activePlayerNodes: [AVAudioPlayerNode] = []
    private let nodesLock = NSLock()

    public init() {
        audioEngine = AVAudioEngine()
        mainMixer = audioEngine.mainMixerNode
        audioEngine.prepare()
    }

    /// Stop and detach all active player nodes before starting new sounds.
    /// This prevents the AVFAudio crash that occurs when stop() is called while
    /// sounds are still playing (dispatch_sync on already-owned queue).
    private func stopAllActiveNodes() {
        nodesLock.lock()
        defer { nodesLock.unlock() }
        for node in activePlayerNodes {
            node.stop()
            audioEngine.detach(node)
        }
        activePlayerNodes.removeAll()
    }

    public func play(_ cue: SoundCue) {
        switch cue {
        case .taskStarted:
            playSquareWave(frequency: 440, duration: 0.08)
        case .waitingForReply:
            playSquareWave(frequency: 330, duration: 0.12)
        case .completed:
            playCompletionChiptune()
        case .failed:
            playFailBuzzer()
        }
    }

    public func playIfAllowed(_ cue: SoundCue, mode: SoundMode) {
        switch mode {
        case .all:
            play(cue)
        case .criticalOnly:
            if cue == .completed || cue == .failed {
                play(cue)
            }
        case .mute:
            break
        }
    }

    private func playCompletionChiptune() {
        // Pleasant bell-like chime using sine wave with harmonics
        // Base frequencies: C5, E5, G5, C6 with overtone harmonics
        let notes: [(frequency: Double, amplitude: Float, delay: Double)] = [
            // C5 with harmonic
            (523.25, 0.4, 0.0),
            (1046.50, 0.15, 0.0),  // C6 overtone
            // E5 with harmonic
            (659.25, 0.35, 0.12),
            (1318.51, 0.12, 0.12), // E6 overtone
            // G5 with harmonic
            (783.99, 0.3, 0.24),
            (1567.98, 0.1, 0.24),  // G6 overtone
            // C6 final
            (1046.50, 0.4, 0.36),
            (2093.00, 0.15, 0.36), // C7 overtone
        ]
        let noteDuration: Double = 0.15

        for note in notes {
            playSineWaveAsync(frequency: note.frequency, amplitude: note.amplitude, duration: noteDuration, delay: note.delay)
        }
    }

    private func playSquareWave(frequency: Double, duration: Double) {
        do {
            if !audioEngine.isRunning {
                try audioEngine.start()
            }
        } catch {
            return
        }

        // Stop any currently playing sounds before starting new one
        stopAllActiveNodes()

        let sampleRate = audioEngine.mainMixerNode.outputFormat(forBus: 0).sampleRate
        let frameCount = AVAudioFrameCount(sampleRate * duration)

        guard let buffer = AVAudioPCMBuffer(pcmFormat: AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!, frameCapacity: frameCount) else {
            return
        }

        buffer.frameLength = frameCount

        let twoPi = 2.0 * Double.pi

        let data = buffer.floatChannelData![0]
        for frame in 0..<Int(frameCount) {
            let phase = twoPi * frequency * Double(frame) / sampleRate
            let squareValue: Float = sin(phase) > 0 ? 0.3 : -0.3
            let envelope = Float(1.0 - (Double(frame) / Double(frameCount)))
            data[frame] = squareValue * envelope
        }

        let playerNode = AVAudioPlayerNode()
        audioEngine.attach(playerNode)
        audioEngine.connect(playerNode, to: mainMixer, format: buffer.format)

        // Track this node so it can be stopped if needed
        nodesLock.lock()
        activePlayerNodes.append(playerNode)
        nodesLock.unlock()

        playerNode.scheduleBuffer(buffer) { [weak self] in
            guard let self else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.nodesLock.lock()
                self.activePlayerNodes.removeAll { $0 === playerNode }
                self.nodesLock.unlock()
                self.audioEngine.detach(playerNode)
            }
        }

        playerNode.play()
    }

    private func playSquareWaveAsync(frequency: Double, duration: Double, delay: Double) {
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.playSquareWave(frequency: frequency, duration: duration)
        }
    }

    private func playSineWaveAsync(frequency: Double, amplitude: Float, duration: Double, delay: Double) {
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.playSineWave(frequency: frequency, amplitude: amplitude, duration: duration)
        }
    }

    private func playSineWave(frequency: Double, amplitude: Float, duration: Double) {
        do {
            if !audioEngine.isRunning {
                try audioEngine.start()
            }
        } catch {
            return
        }

        // Stop any currently playing sounds before starting new one
        stopAllActiveNodes()

        let sampleRate = audioEngine.mainMixerNode.outputFormat(forBus: 0).sampleRate
        let frameCount = AVAudioFrameCount(sampleRate * duration)

        guard let buffer = AVAudioPCMBuffer(pcmFormat: AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!, frameCapacity: frameCount) else {
            return
        }

        buffer.frameLength = frameCount

        let twoPi = 2.0 * Double.pi

        let data = buffer.floatChannelData![0]
        let attackTime = 0.01  // 10ms attack
        let releaseTime = 0.05 // 50ms release
        let attackFrames = Int(sampleRate * attackTime)
        let releaseFrames = Int(sampleRate * releaseTime)
        let sustainFrames = Int(frameCount) - attackFrames - releaseFrames

        for frame in 0..<Int(frameCount) {
            let phase = twoPi * frequency * Double(frame) / sampleRate
            let sineValue = sin(phase)

            // ADSR envelope
            let envelope: Float
            if frame < attackFrames {
                envelope = Float(frame) / Float(attackFrames)
            } else if frame < attackFrames + sustainFrames {
                envelope = 1.0
            } else {
                let releaseFrame = frame - attackFrames - sustainFrames
                envelope = 1.0 - (Float(releaseFrame) / Float(releaseFrames))
            }

            data[frame] = Float(sineValue) * amplitude * envelope * 0.5
        }

        let playerNode = AVAudioPlayerNode()
        audioEngine.attach(playerNode)
        audioEngine.connect(playerNode, to: mainMixer, format: buffer.format)

        // Track this node so it can be stopped if needed
        nodesLock.lock()
        activePlayerNodes.append(playerNode)
        nodesLock.unlock()

        playerNode.scheduleBuffer(buffer) { [weak self] in
            guard let self else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.nodesLock.lock()
                self.activePlayerNodes.removeAll { $0 === playerNode }
                self.nodesLock.unlock()
                self.audioEngine.detach(playerNode)
            }
        }

        playerNode.play()
    }

    private func playFailBuzzer() {
        playSquareWave(frequency: 150, duration: 0.3)
    }
}

public struct NoOpSoundPlayer: SoundPlaying {
    public init() {}

    public func play(_ cue: SoundCue) {}

    public func playIfAllowed(_ cue: SoundCue, mode: SoundMode) {}
}
