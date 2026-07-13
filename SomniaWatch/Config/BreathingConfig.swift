import Foundation

/// Timing constants for the guided breathing session.
///
/// NOTE — intentional divergence from the phone app: `constants/timing.ts`
/// still uses the 6s -> 10s / 35-5-55-5 config. This file uses a different
/// ramp (11 -> 5.5 bpm) and a continuous 40/60 in/out split with no holds,
/// per product's Apple-Breathe-style haptic redesign. This is a deliberate,
/// reviewed choice, not drift — do NOT "fix" it back to match timing.ts
/// without checking with product/science first (see CLAUDE.md: ramp
/// constants are not canonicalized across the repo).
enum BreathingConfig {
    /// Commanded breathing pace at the start/end of a session. The ramp's
    /// endpoints are the product decision (11 -> 5.5 bpm); durations derive.
    static let startBpm: Double = 11.0
    static let endBpm: Double = 5.5

    /// Duration (seconds) of the very first breath cycle in a session.
    static let startBreathDuration: TimeInterval = 60.0 / startBpm
    /// Duration (seconds) of the final breath cycle in a session.
    static let endBreathDuration: TimeInterval = 60.0 / endBpm

    /// Fraction of a single breath spent inhaling.
    static let inhaleFraction: Double = 0.40
    /// No holds in this design — the breath is a continuous in/out wave.
    static let peakHoldFraction: Double = 0.0
    /// Fraction of a single breath spent exhaling.
    static let exhaleFraction: Double = 0.60
    static let troughHoldFraction: Double = 0.0

    /// Available session lengths, in minutes.
    static let sessionDurationsMinutes: [Int] = [8, 12]

    /// Wind-down period at the end of a session (seconds). The phone app
    /// uses this to soften visuals/audio near the end; the watch doesn't
    /// need any special behavior beyond simply completing the session.
    static let windDownDuration: TimeInterval = 30.0
}
