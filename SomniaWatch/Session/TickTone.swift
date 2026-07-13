import AVFoundation

/// Short synthesized beeps that mirror the haptic ticks — one blip per tap,
/// higher and longer at the top of the breath. Buffers are synthesized once
/// at init (no audio assets); playback goes through a single player node so
/// rapid ticks retrigger cleanly. All failures are silent by design: audio
/// is an accent on top of the haptics, never a dependency.
@MainActor
final class TickTone {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var tickBuffer: AVAudioPCMBuffer?
    private var peakBuffer: AVAudioPCMBuffer?
    private var troughBuffer: AVAudioPCMBuffer?
    private var completeBuffer: AVAudioPCMBuffer?
    private var isRunning = false

    private static let sampleRate: Double = 44_100

    init() {
        let format = AVAudioFormat(standardFormatWithSampleRate: Self.sampleRate, channels: 1)
        guard let format else { return }
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)

        tickBuffer = Self.blip(frequency: 880, duration: 0.045, amplitude: 0.30, format: format)
        peakBuffer = Self.blip(frequency: 1318.5, duration: 0.09, amplitude: 0.38, format: format)
        // A fifth below the tick — reads as "settle/turn down" at the trough,
        // mirroring the peak's higher "lift" blip.
        troughBuffer = Self.blip(frequency: 587.3, duration: 0.09, amplitude: 0.38, format: format)
        completeBuffer = Self.blip(frequency: 1568, duration: 0.18, amplitude: 0.38, format: format)
    }

    /// Call when a session starts. `.ambient` mixes with other audio and
    /// respects the mute switch — muting the watch silences beeps but the
    /// haptics keep pacing.
    func start() {
        guard !isRunning else { return }
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
        do {
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
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        isRunning = false
    }

    func play(_ tap: HapticPacer.Tap) {
        guard isRunning else { return }
        let buffer: AVAudioPCMBuffer? = switch tap {
        case .tick: tickBuffer
        case .peak: peakBuffer
        case .trough: troughBuffer
        case .complete: completeBuffer
        }
        guard let buffer else { return }
        player.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
    }

    /// A sine blip with a 5ms attack and exponential decay — reads as a soft
    /// "tick", not an alarm.
    private static func blip(frequency: Double, duration: Double, amplitude: Float,
                             format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let frameCount = AVAudioFrameCount(duration * sampleRate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let samples = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frameCount
        let attackFrames = Int(0.005 * sampleRate)
        for frame in 0..<Int(frameCount) {
            let t = Double(frame) / sampleRate
            let sine = sin(2.0 * .pi * frequency * t)
            let attack = frame < attackFrames ? Float(frame) / Float(attackFrames) : 1
            let decay = Float(exp(-6.0 * t / duration))
            samples[frame] = Float(sine) * amplitude * attack * decay
        }
        return buffer
    }
}
