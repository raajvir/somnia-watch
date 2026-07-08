import SwiftUI

/// Shown after a session ends (naturally or via "End"): the recap card plus
/// an "Exit" button back to the home screen.
struct SummaryView: View {
    let record: SessionRecord
    let onDone: () -> Void

    var body: some View {
        ZStack {
            SomniaColors.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    Color.clear.frame(height: 4)

                    SessionSummaryCard(record: record)

                    Button(action: onDone) {
                        Text("Exit")
                            .font(SomniaFont.bold(14))
                            .foregroundStyle(.white.opacity(0.6))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(.white.opacity(0.25), lineWidth: 1.5)
                            )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 18)
                    .padding(.top, 2)
                    .padding(.bottom, 8)
                }
            }
            // This ScrollView never actually opted out of the safe area —
            // the previous top-padding tweaks were compensating for nothing,
            // same mistake as Home. This is the real fix.
            .ignoresSafeArea(edges: .top)
            // Without this, watchOS auto-focuses the lone Button below and
            // scrolls straight to it, so the screen opens mid-list instead
            // of at "Session complete".
            .defaultScrollAnchor(.top)
            .tint(SomniaColors.accentBright)

            VStack {
                TopFade()
                Spacer()
            }
        }
    }
}

#Preview {
    SummaryView(
        record: SessionRecord(
            startedAt: Date().addingTimeInterval(-8 * 60), completedAt: Date(),
            actualMinutes: 8, totalBreaths: 62,
            averageHeartRate: 64, minHeartRate: 52, maxHeartRate: 78,
            firstHeartRate: 74, lastHeartRate: 55, heartRateSampleCount: 471
        ),
        onDone: {}
    )
}
