import SwiftUI

/// The active breathing session. A gradient bubble expands to fill the whole
/// screen on the inhale and contracts to a small core on the exhale. All
/// readouts use the `.exclusion` blend mode so white text inverts against
/// whatever is behind it — dark over the bright bubble, bright over black —
/// staying legible through the entire breath.
struct SessionView: View {
    let minutes: Int
    @ObservedObject var controller: SessionController
    @ObservedObject var workoutManager: WorkoutManager
    let onFinish: (SessionRecord) -> Void

    @State private var circleScale: CGFloat = Self.troughScale
    @State private var showControls = CommandLine.arguments.contains("-showcontrols")
    @State private var didFinish = false
    @State private var sessionStart = Date()

    private static let baseSize: CGFloat = 200
    private static let troughScale: CGFloat = 0.28

    var body: some View {
        GeometryReader { geo in
            // The bubble only needs to grow enough that its diameter covers
            // the screen's diagonal — anything beyond that is invisible
            // overshoot that made the "fully lit" moment feel stretched out.
            // A small buffer (1.06x) avoids a visible unlit sliver in the
            // corners as the display renders it.
            let diagonal = sqrt(pow(geo.size.width, 2) + pow(geo.size.height, 2))
            let peakScale = (diagonal * 1.06) / Self.baseSize

            ZStack {
                Color.black.ignoresSafeArea()

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [SomniaColors.bubbleCore, SomniaColors.bubbleEdge],
                            center: .center, startRadius: 4,
                            endRadius: Self.baseSize / 2
                        )
                    )
                    .frame(width: Self.baseSize, height: Self.baseSize)
                    .shadow(color: SomniaColors.bubbleEdge.opacity(0.7), radius: 24)
                    .scaleEffect(circleScale)

                readouts
                    .blendMode(.exclusion)

                if showControls {
                    controlsOverlay(peakScale: peakScale)
                        .transition(.opacity)
                }
            }
            // Explicit, not inferred from Color.black.ignoresSafeArea()'s own
            // greedy sizing — that left the ZStack's true bounds ambiguous
            // and it was resolving asymmetrically on some watch models
            // (crown-side safe-area handling differs per size), visibly
            // shifting the centered bubble off-axis on everything but the
            // two largest devices.
            .frame(width: geo.size.width, height: geo.size.height)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeOut(duration: 0.2)) { showControls.toggle() }
            }
            .onAppear { start(peakScale: peakScale) }
            .onChange(of: controller.currentPhase) { _, newPhase in
                animate(to: newPhase, peakScale: peakScale)
            }
            .onChange(of: controller.isComplete) { _, isComplete in
                if isComplete { finish() }
            }
        }
        // Wraps the GeometryReader itself, not just its child ZStack — same
        // scoping mistake as Home/Summary/History. Applied only to the
        // child, `geo.size` still measured the safe-area-shrunk bounds even
        // though the paint bled full-screen, undersizing the peak bubble.
        .ignoresSafeArea()
    }

    private var readouts: some View {
        VStack(spacing: 8) {
            countdownText

            HStack(spacing: 8) {
                metric(value: heartRateValue, unit: "bpm")
                metric(value: hzValue, unit: "Hz")
            }
        }
        .foregroundStyle(.white)
    }

    /// M:SS countdown, minute in the large weight with the seconds trailing
    /// smaller — a clock reading, not a "minutes left" label.
    private var countdownText: some View {
        let total = max(0, Int(controller.remainingTime.rounded(.up)))
        let m = total / 60
        let s = total % 60
        return (Text("\(m)").font(SomniaFont.black(46))
            + Text(String(format: ":%02d", s)).font(SomniaFont.bold(26)))
    }

    private func metric(value: String, unit: String) -> some View {
        (Text(value).font(SomniaFont.bold(12)) + Text(" " + unit).font(SomniaFont.regular(12)))
    }

    private func controlsOverlay(peakScale: CGFloat) -> some View {
        VStack {
            Spacer()
            HStack(spacing: 10) {
                controlButton(title: "Restart", tint: .white.opacity(0.14)) {
                    restart(peakScale: peakScale)
                }
                controlButton(title: "End", tint: .white.opacity(0.14), action: finish)
            }
            .padding(.bottom, 8)
        }
    }

    private func controlButton(title: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(SomniaFont.bold(13))
                .foregroundStyle(.white)
                .padding(.vertical, 8)
                .padding(.horizontal, 18)
                .background(Capsule().fill(tint))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Derived labels

    private var heartRateValue: String {
        guard let bpm = workoutManager.latestHeartRate else { return "--" }
        return "\(Int(bpm.rounded()))"
    }

    /// Commanded breathing frequency (Hz) for the current breath — i.e. the
    /// pace we're guiding to, derived from the current breath's total duration.
    private var hzValue: String {
        let dur = controller.currentBreathTimeline.totalDuration
        guard dur > 0 else { return "--" }
        return String(format: "%.2f", 1.0 / dur)
    }

    // MARK: - Lifecycle

    private func start(peakScale: CGFloat) {
        circleScale = Self.troughScale
        sessionStart = Date()
        didFinish = false
        Task {
            await workoutManager.requestAuthorization()
            workoutManager.start()
        }
        controller.start(minutes: minutes)
        // `currentPhase` already defaults to .inhale, so if the session also
        // starts on .inhale, SwiftUI's onChange sees no transition and the
        // very first breath's growth never fires. Kick it off explicitly.
        animate(to: controller.currentPhase, peakScale: peakScale)
    }

    /// Restarts the same session from breath 1 without leaving this view —
    /// avoids the app-level screen-swap this used to rely on, which never
    /// reliably re-armed the controller's timer.
    private func restart(peakScale: CGFloat) {
        showControls = false
        controller.stop()
        workoutManager.stop()
        start(peakScale: peakScale)
    }

    private func animate(to phase: BreathPhase, peakScale: CGFloat) {
        let timeline = controller.currentBreathTimeline
        switch phase {
        case .inhale:
            withAnimation(.easeInOut(duration: timeline.inhale)) {
                circleScale = peakScale
            }
        case .exhale:
            withAnimation(.easeInOut(duration: timeline.exhale)) {
                circleScale = Self.troughScale
            }
        case .peakHold, .troughHold:
            break // Hold at the scale reached by the preceding animation.
        }
    }

    private func finish() {
        guard !didFinish else { return }
        didFinish = true

        controller.stop()
        workoutManager.stop()

        let actualMinutes = max(1, Int((Date().timeIntervalSince(sessionStart) / 60.0).rounded()))
        let record = SessionRecord(
            startedAt: sessionStart,
            completedAt: Date(),
            actualMinutes: actualMinutes,
            totalBreaths: controller.currentBreathIndex + (controller.isComplete ? 1 : 0),
            averageHeartRate: workoutManager.averageHeartRate,
            minHeartRate: workoutManager.minHeartRate,
            maxHeartRate: workoutManager.maxHeartRate,
            firstHeartRate: workoutManager.firstHeartRate,
            lastHeartRate: workoutManager.latestHeartRate,
            heartRateSampleCount: workoutManager.heartRateSampleCount
        )
        onFinish(record)
    }
}

#Preview {
    SessionView(
        minutes: 8,
        controller: SessionController(),
        workoutManager: WorkoutManager(),
        onFinish: { _ in }
    )
}
