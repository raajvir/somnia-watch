import WatchKit

/// Paces breathing with mirrored haptic ticks: they accelerate through the
/// inhale, crescendo in one stronger tap at the top of the breath, then
/// decelerate through the exhale — the tap rhythm IS the breath wave.
/// watchOS offers no amplitude control (only fixed WKHapticType patterns),
/// so all pacing lives in tap timing + type choice.
@MainActor
final class HapticPacer {
    enum Tap { case tick, peak, complete }

    /// Fired on the main actor at the moment each haptic is played —
    /// drives the on-screen sync indicator.
    var onTap: ((Tap) -> Void)?

    /// Widest gap between ticks (start of inhale / end of exhale).
    private let maxGap: TimeInterval = 0.60
    /// Tightest gap (top of the breath). watchOS drops taps much below
    /// ~0.15s spacing, so this is the practical crescendo ceiling.
    private let minGap: TimeInterval = 0.15

    private var tapTask: Task<Void, Never>?

    func phaseChanged(to phase: BreathPhase, timeline: BreathPhaseTimeline) {
        cancelTaps()
        switch phase {
        case .inhale:
            // Trough -> peak: gaps shrink. First tick right at the trough.
            let offsets = Self.rampOffsets(duration: timeline.inhale,
                                           startGap: maxGap, endGap: minGap,
                                           includeZero: true)
            run(offsets: offsets)
        case .exhale:
            // Top of the breath: the crescendo tap, then ticks widen back out.
            play(.peak)
            let offsets = Self.rampOffsets(duration: timeline.exhale,
                                           startGap: minGap, endGap: maxGap,
                                           includeZero: false)
            run(offsets: offsets)
        case .peakHold, .troughHold:
            break // zero-duration in the current config
        }
    }

    func stop() { cancelTaps() }

    func playSessionComplete() {
        cancelTaps()
        play(.complete)
    }

    private func run(offsets: [TimeInterval]) {
        guard !offsets.isEmpty else { return }
        tapTask = Task { @MainActor in
            let start = ContinuousClock.now
            for offset in offsets {
                try? await Task.sleep(until: start + .seconds(offset),
                                      tolerance: .milliseconds(10),
                                      clock: .continuous)
                if Task.isCancelled { return }
                play(.tick)
            }
        }
    }

    private func play(_ tap: Tap) {
        switch tap {
        case .tick: WKInterfaceDevice.current().play(.click)
        case .peak: WKInterfaceDevice.current().play(.directionUp)
        case .complete: WKInterfaceDevice.current().play(.success)
        }
        onTap?(tap)
    }

    private func cancelTaps() {
        tapTask?.cancel()
        tapTask = nil
    }

    /// Tick times within a phase. Gaps interpolate linearly from `startGap`
    /// to `endGap` across the phase, so the rhythm accelerates (inhale) or
    /// relaxes (exhale). `includeZero` controls a tick at t=0 — the exhale
    /// skips it because the peak tap owns that instant. No tick lands within
    /// half the terminal gap of the phase's end, so phase-boundary taps
    /// never stack. Exposed for testing.
    static func rampOffsets(duration: TimeInterval,
                            startGap: TimeInterval,
                            endGap: TimeInterval,
                            includeZero: Bool) -> [TimeInterval] {
        guard duration > min(startGap, endGap) else { return includeZero ? [0] : [] }
        var offsets: [TimeInterval] = includeZero ? [0] : []
        var t: TimeInterval = 0
        while true {
            let progress = min(1, t / duration)
            let gap = startGap + (endGap - startGap) * progress
            t += gap
            if t > duration - endGap * 0.5 { break }
            offsets.append(t)
        }
        return offsets
    }
}
