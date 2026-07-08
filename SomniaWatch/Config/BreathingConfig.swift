import Foundation

/// Timing constants for the guided breathing session.
///
/// These MUST mirror the phone app's `constants/timing.ts`. If you change a
/// value here, change it there too (and vice versa) — the two apps are
/// expected to feel identical.
enum BreathingConfig {
    /// Duration (seconds) of the very first breath cycle in a session.
    static let startBreathDuration: TimeInterval = 6.0

    /// Duration (seconds) of the final breath cycle in a session.
    static let endBreathDuration: TimeInterval = 10.0

    /// Fraction of a single breath spent inhaling.
    static let inhaleFraction: Double = 0.35
    /// Fraction of a single breath spent holding at the peak (lungs full).
    static let peakHoldFraction: Double = 0.05
    /// Fraction of a single breath spent exhaling.
    static let exhaleFraction: Double = 0.55
    /// Fraction of a single breath spent holding at the trough (lungs empty).
    static let troughHoldFraction: Double = 0.05

    /// Available session lengths, in minutes.
    static let sessionDurationsMinutes: [Int] = [8, 12]

    /// Wind-down period at the end of a session (seconds). The phone app
    /// uses this to soften visuals/audio near the end; the watch doesn't
    /// need any special behavior beyond simply completing the session.
    static let windDownDuration: TimeInterval = 30.0
}
