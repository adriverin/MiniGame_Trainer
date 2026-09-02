import UIKit
import AVFoundation

/// Haptic and audio feedback shared by all games. Respects `UserPreferences`.
/// Sounds are synthesized at launch (short sine bursts) so no audio assets are required.
@MainActor
final class FeedbackService {
    private let preferences: UserPreferences
    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let rigidImpact = UIImpactFeedbackGenerator(style: .rigid)
    private let notification = UINotificationFeedbackGenerator()
    private let sound = SynthesizedSoundPlayer()

    init(preferences: UserPreferences) {
        self.preferences = preferences
    }

    /// Call shortly before gameplay so the first haptic/audio event has no warm-up latency.
    func prepare() {
        lightImpact.prepare()
        rigidImpact.prepare()
        notification.prepare()
        if preferences.soundEnabled {
            sound.start()
        }
    }

    func stop() {
        sound.stop()
    }

    func tapSucceeded() {
        if preferences.hapticsEnabled {
            lightImpact.impactOccurred(intensity: 0.7)
            lightImpact.prepare()
        }
        if preferences.soundEnabled {
            sound.play(.tap)
        }
    }

    func countdownTick() {
        if preferences.hapticsEnabled {
            rigidImpact.impactOccurred(intensity: 0.5)
        }
        if preferences.soundEnabled {
            sound.play(.tick)
        }
    }

    func gameFailed() {
        if preferences.hapticsEnabled {
            notification.notificationOccurred(.error)
        }
        if preferences.soundEnabled {
            sound.play(.fail)
        }
    }
}

/// Minimal AVAudioEngine player for a few procedurally generated buffers.
private final class SynthesizedSoundPlayer {
    enum Clip: CaseIterable {
        case tap, tick, fail
    }

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var buffers: [Clip: AVAudioPCMBuffer] = [:]
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)
    private var isRunning = false

    init() {
        guard let format else { return }
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = 0.5
        for clip in Clip.allCases {
            buffers[clip] = makeBuffer(for: clip, format: format)
        }
    }

    func start() {
        guard !isRunning else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            try engine.start()
            player.play()
            isRunning = true
        } catch {
            isRunning = false
        }
    }

    func stop() {
        guard isRunning else { return }
        player.stop()
        engine.stop()
        isRunning = false
    }

    func play(_ clip: Clip) {
        guard isRunning, let buffer = buffers[clip] else { return }
        player.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
    }

    private func makeBuffer(for clip: Clip, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let sampleRate = format.sampleRate
        let (frequency, duration, gain): (Double, Double, Float) = switch clip {
        case .tap: (880, 0.05, 0.6)
        case .tick: (660, 0.08, 0.5)
        case .fail: (180, 0.35, 0.7)
        }
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let channel = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frameCount
        for frame in 0..<Int(frameCount) {
            let t = Double(frame) / sampleRate
            let envelope = Float(1 - t / duration)
            channel[frame] = Float(sin(2 * .pi * frequency * t)) * envelope * envelope * gain
        }
        return buffer
    }
}
