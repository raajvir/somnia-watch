import Foundation

/// Drives a single breathing session: which breath we're on, which phase of
/// that breath we're in, and how much time remains.
///
/// Wall-clock anchored: every tick recomputes state from `Date().timeIntervalSince(startDate)`
/// rather than accumulating timer ticks, so the session stays correct even
/// if the app is briefly suspended (e.g. the watch dims/backgrounds it).
@MainActor
final class SessionController: ObservableObject {
    @Published private(set) var currentPhase: BreathPhase = .inhale
    @Published private(set) var currentBreathIndex: Int = 0
    /// Overall session progress, 0 (just started) ... 1 (finished).
    @Published private(set) var progress: Double = 0
    /// Seconds remaining in the whole session.
    @Published private(set) var remainingTime: TimeInterval = 0
    @Published private(set) var isComplete: Bool = false

    /// Phase durations for the breath currently in progress. The view uses
    /// this to size its inhale/exhale animations to match the current
    /// (progressively slowing) breath pace.
    @Published private(set) var currentBreathTimeline: BreathPhaseTimeline =
        BreathingEngine.phaseTimeline(for: BreathingConfig.startBreathDuration)

    /// Total number of breaths in the session (known once `start` is called).
    private(set) var totalBreathCount: Int = 0

    private var breathDurations: [TimeInterval] = []
    /// Cumulative start offset (seconds from session start) of each breath.
    private var breathStartOffsets: [TimeInterval] = []
    private var totalDuration: TimeInterval = 0
    private var startDate: Date?
    private var timer: Timer?
    private var onComplete: (() -> Void)?

    /// How often we recompute phase/breath from the wall clock. Must be
    /// smaller than the shortest possible phase (a hold phase can be as
    /// short as 5% of a 6s breath, i.e. ~0.3s) so transitions aren't missed.
    private let tickInterval: TimeInterval = 0.05

    /// Starts a new session lasting `minutes` minutes.
    func start(minutes: Int, onComplete: @escaping () -> Void = {}) {
        stop()

        let total = TimeInterval(minutes * 60)
        let durations = BreathingEngine.generateBreathDurations(totalTime: total)

        breathDurations = durations
        totalDuration = total
        totalBreathCount = durations.count
        self.onComplete = onComplete

        var offsets: [TimeInterval] = []
        offsets.reserveCapacity(durations.count)
        var cumulative: TimeInterval = 0
        for d in durations {
            offsets.append(cumulative)
            cumulative += d
        }
        breathStartOffsets = offsets

        currentBreathIndex = 0
        currentPhase = .inhale
        isComplete = false
        remainingTime = total
        progress = 0
        currentBreathTimeline = durations.first.map(BreathingEngine.phaseTimeline(for:))
            ?? BreathingEngine.phaseTimeline(for: BreathingConfig.startBreathDuration)

        startDate = Date()
        HapticPacer.play(for: .inhale)

        let newTimer = Timer(timeInterval: tickInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
        RunLoop.main.add(newTimer, forMode: .common)
        timer = newTimer
    }

    /// Cancels the session without marking it complete.
    func stop() {
        timer?.invalidate()
        timer = nil
        startDate = nil
    }

    private func tick() {
        guard let startDate, !isComplete else { return }
        let elapsed = Date().timeIntervalSince(startDate)

        if elapsed >= totalDuration || breathStartOffsets.isEmpty {
            complete()
            return
        }

        remainingTime = max(0, totalDuration - elapsed)
        progress = totalDuration > 0 ? min(1, elapsed / totalDuration) : 1

        // Breaths are ordered and elapsed time only grows, so scan forward
        // from the current breath instead of rescanning from the start.
        var index = currentBreathIndex
        while index + 1 < breathStartOffsets.count && breathStartOffsets[index + 1] <= elapsed {
            index += 1
        }

        let breathStart = breathStartOffsets[index]
        let breathDuration = breathDurations[index]
        let timeline = BreathingEngine.phaseTimeline(for: breathDuration)
        let elapsedInBreath = elapsed - breathStart
        let phase = resolvePhase(at: elapsedInBreath, in: timeline)

        if index != currentBreathIndex {
            currentBreathIndex = index
            currentBreathTimeline = timeline
        }

        if phase != currentPhase {
            currentPhase = phase
            HapticPacer.play(for: phase)
        }
    }

    private func resolvePhase(at elapsedInBreath: TimeInterval, in timeline: BreathPhaseTimeline) -> BreathPhase {
        var cumulative: TimeInterval = 0
        for phase in BreathPhase.allCases {
            cumulative += timeline.duration(for: phase)
            if elapsedInBreath < cumulative {
                return phase
            }
        }
        return .troughHold
    }

    private func complete() {
        timer?.invalidate()
        timer = nil
        remainingTime = 0
        progress = 1
        isComplete = true
        HapticPacer.playSessionComplete()
        onComplete?()
    }
}
