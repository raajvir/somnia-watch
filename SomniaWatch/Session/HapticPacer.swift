import WatchKit

/// Paces breathing with Apple-Breathe-style haptics: light taps that
/// accelerate through the inhale, a stronger tap at the top of the breath,
/// then silence through the exhale so the release reads as "let go".
@MainActor
final class HapticPacer {
    /// Gap between taps at the start of an inhale (seconds).
    private let startGap: TimeInterval = 0.50
    /// Gap between taps as the inhale completes (seconds).
    private let endGap: TimeInterval = 0.15

    private var tapTask: Task<Void, Never>?

    /// Call whenever a new breath phase begins.
    func phaseChanged(to phase: BreathPhase, timeline: BreathPhaseTimeline) {
        cancelTaps()
        switch phase {
        case .inhale:
            startInhaleTaps(duration: timeline.inhale)
        case .peakHold:
            // Crescendo at the top of the breath.
            WKInterfaceDevice.current().play(.directionUp)
        case .exhale, .troughHold:
            break // intentionally silent
        }
    }

    /// Call when the session is stopped or exited early.
    func stop() {
        cancelTaps()
    }

    /// Call once, when the whole session finishes.
    func playSessionComplete() {
        WKInterfaceDevice.current().play(.success)
    }

    private func startInhaleTaps(duration: TimeInterval) {
        let offsets = Self.tapOffsets(inhaleDuration: duration,
                                      startGap: startGap, endGap: endGap)
        guard !offsets.isEmpty else { return }
        tapTask = Task { @MainActor in
            let start = ContinuousClock.now
            for offset in offsets {
                try? await Task.sleep(until: start + .seconds(offset), clock: .continuous)
                if Task.isCancelled { return }
                WKInterfaceDevice.current().play(.click)
            }
        }
    }

    private func cancelTaps() {
        tapTask?.cancel()
        tapTask = nil
    }

    /// Tap times (seconds from inhale start). First tap at 0; successive gaps
    /// shrink linearly from `startGap` to `endGap` across the inhale, so the
    /// rhythm accelerates toward the top of the breath. No tap lands within
    /// `endGap` of the inhale's end — the peak-hold crescendo tap owns that
    /// moment. Exposed for testing.
    static func tapOffsets(inhaleDuration: TimeInterval,
                           startGap: TimeInterval,
                           endGap: TimeInterval) -> [TimeInterval] {
        guard inhaleDuration > startGap else { return [0] }
        var offsets: [TimeInterval] = [0]
        var t: TimeInterval = 0
        while true {
            let progress = min(1, t / inhaleDuration)
            let gap = startGap + (endGap - startGap) * progress
            t += gap
            if t > inhaleDuration - endGap { break }
            offsets.append(t)
        }
        return offsets
    }
}
