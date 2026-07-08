import SwiftUI

/// Diagnostic screen for the closed-loop prototype: every raw signal we can
/// actually read from the watch, live, with nothing derived or smoothed by
/// us. Three honest tiers, labeled by how often each one really updates —
/// see the captions, not just the numbers.
struct LiveDataView: View {
    let onClose: () -> Void

    @StateObject private var workout = WorkoutManager()
    @StateObject private var motion = MotionManager()

    var body: some View {
        ZStack {
            SomniaColors.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 8) {
                    Color.clear.frame(height: 4)

                    ZStack {
                        // Title centered via an asymmetric trailing spacer —
                        // same pattern as HomeView's header — so it reserves
                        // room for the system clock on the right. A plain
                        // centered title placed its trailing edge right under
                        // the clock digits on the narrowest screen (SE 40mm).
                        HStack {
                            Spacer(minLength: 0)
                            Text("Live Data")
                                .font(SomniaFont.bold(15))
                                .foregroundStyle(.white)
                            Spacer(minLength: 54)
                        }
                        HStack {
                            Button(action: onClose) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.75))
                                    .frame(width: 26, height: 26)
                                    .background(Circle().fill(.white.opacity(0.12)))
                            }
                            .buttonStyle(.plain)
                            Spacer()
                        }
                    }
                    .padding(.bottom, 6)

                    section(title: "HEART RATE", caption: "~1 sample every 1–5 sec") {
                        row("Latest", value(workout.latestHeartRate, "bpm"))
                        row("Average", value(workout.averageHeartRate, "bpm"))
                        row("Range", rangeValue(workout.minHeartRate, workout.maxHeartRate, "bpm"))
                        row("Samples", "\(workout.heartRateSampleCount)")
                    }

                    section(title: "HEART RATE VARIABILITY", caption: "SDNN — every 1–5 min, not continuous") {
                        row("Latest SDNN", value(workout.latestHRV, "ms"))
                        row("Samples", "\(workout.hrvSampleCount)")
                    }

                    section(title: "MOTION", caption: motion.isAvailable ? "Device motion, ~20 Hz" : "Unavailable on this device") {
                        row("Accel X", fixedValue(motion.accel.x, "g"))
                        row("Accel Y", fixedValue(motion.accel.y, "g"))
                        row("Accel Z", fixedValue(motion.accel.z, "g"))
                        row("User accel mag", fixedValue(magnitude(motion.userAccel), "g"))
                        row("Rotation X", fixedValue(motion.rotationRate.x, "rad/s"))
                        row("Rotation Y", fixedValue(motion.rotationRate.y, "rad/s"))
                        row("Rotation Z", fixedValue(motion.rotationRate.z, "rad/s"))
                    }

                    Text("Not shown because it isn't actually available live: breathing rate (Apple only computes this during sleep), raw beat-to-beat intervals (no third-party API), blood oxygen (background-only, and disabled on newer US models), ECG (on-demand only).")
                        .font(SomniaFont.regular(9.5))
                        .foregroundStyle(.white.opacity(0.35))
                        .padding(.horizontal, 18)
                        .padding(.top, 6)
                        .padding(.bottom, 12)
                }
            }
            .ignoresSafeArea(edges: .top)
            .defaultScrollAnchor(.top)
            .tint(SomniaColors.accentBright)

            VStack {
                TopFade()
                Spacer()
            }
        }
        .onAppear {
            Task { await workout.requestAuthorization() }
            workout.start()
            motion.start()
        }
        .onDisappear {
            workout.stop()
            motion.stop()
        }
    }

    @ViewBuilder
    private func section<Content: View>(title: String, caption: String, @ViewBuilder rows: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(SomniaFont.bold(11))
                    .foregroundStyle(SomniaColors.accentBright)
                    .tracking(0.5)
                Text(caption)
                    .font(SomniaFont.regular(9.5))
                    .foregroundStyle(.white.opacity(0.4))
            }

            VStack(spacing: 6) {
                rows()
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.white.opacity(0.06))
            )
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(SomniaFont.regular(11))
                .foregroundStyle(.white.opacity(0.55))
            Spacer(minLength: 8)
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white)
        }
    }

    private func value(_ v: Double?, _ unit: String) -> String {
        guard let v else { return "--" }
        return "\(Int(v.rounded())) \(unit)"
    }

    private func rangeValue(_ min: Double?, _ max: Double?, _ unit: String) -> String {
        guard let min, let max else { return "--" }
        return "\(Int(min.rounded()))–\(Int(max.rounded())) \(unit)"
    }

    private func fixedValue(_ v: Double, _ unit: String) -> String {
        String(format: "% .2f %@", v, unit)
    }

    private func magnitude(_ v: (x: Double, y: Double, z: Double)) -> Double {
        sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
    }
}

#Preview {
    LiveDataView(onClose: {})
}
