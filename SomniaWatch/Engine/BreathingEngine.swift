import Foundation

/// The four phases of a single breath cycle, in order.
enum BreathPhase: CaseIterable {
    case inhale
    case peakHold
    case exhale
    case troughHold
}

/// A breath cycle split into its four phase durations (seconds).
struct BreathPhaseTimeline {
    let inhale: TimeInterval
    let peakHold: TimeInterval
    let exhale: TimeInterval
    let troughHold: TimeInterval

    /// Total duration of the breath (sum of all phases).
    var totalDuration: TimeInterval {
        inhale + peakHold + exhale + troughHold
    }

    /// Duration of a given phase.
    func duration(for phase: BreathPhase) -> TimeInterval {
        switch phase {
        case .inhale: return inhale
        case .peakHold: return peakHold
        case .exhale: return exhale
        case .troughHold: return troughHold
        }
    }

    /// The (start, end) offset — measured from the start of the breath — for
    /// a given phase.
    func range(for phase: BreathPhase) -> (start: TimeInterval, end: TimeInterval) {
        var start: TimeInterval = 0
        for p in BreathPhase.allCases {
            let d = duration(for: p)
            if p == phase {
                return (start, start + d)
            }
            start += d
        }
        return (totalDuration, totalDuration)
    }
}

/// Pure, testable engine that generates the sequence of breath durations for
/// a session and splits any single breath duration into its phase timeline.
///
/// This is a Swift port of the phone app's `generateBreathDurations`
/// (see `app/session.tsx`). The algorithm must stay behaviorally identical:
/// 1. Start with just [start, end].
/// 2. Keep incrementing the breath count and recomputing a uniform linear
///    interpolation from start -> end across that many breaths, until the
///    cumulative sum of durations is >= totalTime.
/// 3. Trim/clamp the final list so the cumulative sum never exceeds
///    totalTime (the loop above can overshoot on its last iteration).
enum BreathingEngine {
    /// Generates the list of breath durations (seconds) that make up a
    /// session of `totalTime` seconds, linearly interpolating from
    /// `BreathingConfig.startBreathDuration` to `BreathingConfig.endBreathDuration`.
    static func generateBreathDurations(
        totalTime: TimeInterval,
        startDuration: TimeInterval = BreathingConfig.startBreathDuration,
        endDuration: TimeInterval = BreathingConfig.endBreathDuration
    ) -> [TimeInterval] {
        func generateValues(_ a: TimeInterval, _ b: TimeInterval, count: Int) -> [TimeInterval] {
            guard count >= 2 else { return [a, b] }
            let step = (b - a) / TimeInterval(count - 1)
            var values: [TimeInterval] = []
            values.reserveCapacity(count)
            var current = a
            for _ in 0..<count {
                values.append(current)
                current += step
            }
            return values
        }

        var outList: [TimeInterval] = [startDuration, endDuration]
        var count = 2

        // Keep adding breaths until total duration >= session time.
        while outList.reduce(0, +) < totalTime {
            count += 1
            outList = generateValues(startDuration, endDuration, count: count)
        }

        // The loop above can overshoot totalTime on its final iteration (it
        // only stops once the sum is >= totalTime). Clamp/trim so the
        // cumulative sum of the returned durations never exceeds the
        // session length.
        var clamped: [TimeInterval] = []
        var cumulative: TimeInterval = 0
        for dur in outList {
            if cumulative >= totalTime { break }
            let remaining = totalTime - cumulative
            let clampedDur = min(dur, remaining)
            clamped.append(clampedDur)
            cumulative += clampedDur
        }

        return clamped
    }

    /// Splits a single breath's total duration into its four phase
    /// durations, using the fractions defined in `BreathingConfig`.
    static func phaseTimeline(for breathDuration: TimeInterval) -> BreathPhaseTimeline {
        BreathPhaseTimeline(
            inhale: breathDuration * BreathingConfig.inhaleFraction,
            peakHold: breathDuration * BreathingConfig.peakHoldFraction,
            exhale: breathDuration * BreathingConfig.exhaleFraction,
            troughHold: breathDuration * BreathingConfig.troughHoldFraction
        )
    }
}
