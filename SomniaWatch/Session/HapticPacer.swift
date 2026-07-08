import WatchKit

/// Plays the haptic taps that pace a breathing session.
///
/// Hold phases (peak/trough) are intentionally silent — only the
/// inhale/exhale transitions and session completion get haptic feedback,
/// so the taps read as "breathe in" / "breathe out" cues rather than noise.
enum HapticPacer {
    /// Call when a new phase begins.
    static func play(for phase: BreathPhase) {
        switch phase {
        case .inhale:
            WKInterfaceDevice.current().play(.directionUp)
        case .exhale:
            WKInterfaceDevice.current().play(.directionDown)
        case .peakHold, .troughHold:
            break
        }
    }

    /// Call once, when the whole session finishes.
    static func playSessionComplete() {
        WKInterfaceDevice.current().play(.success)
    }
}
