import SwiftUI

/// The stat layout shared by the post-session summary screen and each
/// history detail — so a past night looks exactly like the moment it ended.
///
/// Metric choice is deliberate: everything shown is either an honest
/// measurement (heart rate, from HealthKit) or clearly the paced rate we
/// guided toward (from `BreathingConfig`). We don't yet measure the user's
/// actual breathing rate on-device (that's the closed-loop roadmap work), so
/// nothing here claims to.
struct SessionSummaryCard: View {
    let record: SessionRecord
    /// "Session complete" right after a session vs. a dated title in history.
    var title: String = "Session complete"

    var body: some View {
        VStack(spacing: 12) {
            Image("Wordmark")
                .resizable()
                .scaledToFit()
                .frame(width: 74)
                .opacity(0.9)

            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(SomniaColors.accentBright.opacity(0.35))
                    .frame(width: 168, height: 46)
                    .blur(radius: 18)

                Text(title)
                    .font(SomniaFont.bold(16))
                    .foregroundStyle(SomniaColors.accentBright)
            }
            .padding(.bottom, 4)

            VStack(spacing: 0) {
                Text("\(record.actualMinutes)")
                    .font(SomniaFont.black(44))
                    .foregroundStyle(.white)
                Text("minutes")
                    .font(SomniaFont.regular(12))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(.bottom, 6)

            VStack(spacing: 9) {
                row(label: "Breaths completed", value: "\(record.totalBreaths)")
                row(label: "Breathing pace",
                    value: "\(paceString(record.startPaceBpm)) → \(paceString(record.endPaceBpm))",
                    unit: "bpm")
                row(label: "Start → end", value: startEndString, minScale: 0.7)

                if record.averageHeartRate != nil {
                    heartRateRows
                } else {
                    row(label: "Heart rate", value: "Unavailable")
                }
            }
        }
        .padding(.horizontal, 18)
    }

    @ViewBuilder
    private var heartRateRows: some View {
        if let avg = record.averageHeartRate {
            row(label: "Average heart rate", value: "\(Int(avg.rounded()))", unit: "bpm")
        }
        if let min = record.minHeartRate, let max = record.maxHeartRate {
            row(label: "Heart rate range", value: "\(Int(min.rounded()))–\(Int(max.rounded()))", unit: "bpm")
        }
        if let first = record.firstHeartRate, let last = record.lastHeartRate {
            row(label: "First → last reading",
                value: "\(Int(first.rounded())) → \(Int(last.rounded()))", unit: "bpm")
        }
        if record.heartRateSampleCount > 0 {
            row(label: "Heart rate samples", value: "\(record.heartRateSampleCount)")
        }
    }

    private func row(label: String, value: String, unit: String? = nil, minScale: CGFloat = 0.75) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(SomniaFont.regular(11.5))
                .foregroundStyle(.white.opacity(0.55))
            Spacer(minLength: 8)
            (Text(value).font(SomniaFont.bold(14))
                + Text(unit.map { " " + $0 } ?? "").font(SomniaFont.regular(10.5)))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(minScale)
                .multilineTextAlignment(.trailing)
        }
    }

    private func paceString(_ bpm: Double) -> String {
        String(format: "%.0f", bpm.rounded())
    }

    private func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    /// "4:42 → 4:50 PM" — only one AM/PM suffix when start and end share a
    /// period, so the row reliably fits on one line.
    private var startEndString: String {
        let noPeriod = DateFormatter()
        noPeriod.dateFormat = "h:mm"
        let start = noPeriod.string(from: record.startedAt)
        let end = timeString(record.completedAt)
        return "\(start) → \(end)"
    }
}

#Preview {
    ZStack {
        SomniaColors.background.ignoresSafeArea()
        SessionSummaryCard(record: SessionRecord(
            startedAt: Date().addingTimeInterval(-8 * 60), completedAt: Date(),
            actualMinutes: 8, totalBreaths: 62,
            averageHeartRate: 64, minHeartRate: 52, maxHeartRate: 78,
            firstHeartRate: 74, lastHeartRate: 55, heartRateSampleCount: 471
        ))
    }
}
