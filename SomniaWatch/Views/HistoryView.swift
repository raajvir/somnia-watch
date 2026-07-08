import SwiftUI

/// Past sessions, most recent first. Tapping a row opens the same
/// `SessionSummaryCard` layout used right after a session ends.
struct HistoryView: View {
    @ObservedObject var store: SessionHistoryStore
    let onClose: () -> Void

    @State private var selected: SessionRecord?

    var body: some View {
        ZStack {
            SomniaColors.background.ignoresSafeArea()

            if let selected {
                ScrollView {
                    VStack(spacing: 16) {
                        Color.clear.frame(height: 4)

                        SessionSummaryCard(record: selected, title: dateTitle(selected.completedAt))

                        Button(action: { self.selected = nil }) {
                            Text("Back")
                                .font(SomniaFont.bold(14))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Capsule().fill(.white.opacity(0.14)))
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 18)
                        .padding(.bottom, 8)
                    }
                }
                // Same missing-ignoresSafeArea mistake as Summary and the
                // original Home bug — this ScrollView never actually opted
                // out of the safe area, so it kept the excess top gap.
                .ignoresSafeArea(edges: .top)
                .defaultScrollAnchor(.top)
                .tint(SomniaColors.accentBright)
            } else if store.records.isEmpty {
                emptyState
            } else {
                list
            }

            if selected != nil || !store.records.isEmpty {
                VStack {
                    TopFade()
                    Spacer()
                }
            }
        }
        .navigationTitle("")
    }

    private var list: some View {
        ScrollView {
            VStack(spacing: 8) {
                Color.clear.frame(height: 4)

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
                    Text("History")
                        .font(SomniaFont.bold(15))
                        .foregroundStyle(.white)
                    Spacer()
                    Color.clear.frame(width: 26, height: 26)
                }
                .padding(.bottom, 4)

                ForEach(store.records) { record in
                    Button {
                        selected = record
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(dateTitle(record.completedAt))
                                    .font(SomniaFont.bold(13))
                                    .foregroundStyle(.white)
                                Text("\(record.actualMinutes) min · \(record.totalBreaths) breaths")
                                    .font(SomniaFont.regular(10.5))
                                    .foregroundStyle(.white.opacity(0.55))
                            }
                            Spacer()
                            if let avg = record.averageHeartRate {
                                VStack(alignment: .trailing, spacing: 0) {
                                    Text("\(Int(avg.rounded()))")
                                        .font(SomniaFont.bold(13))
                                        .foregroundStyle(SomniaColors.accentBright)
                                    Text("avg bpm")
                                        .font(SomniaFont.regular(8.5))
                                        .foregroundStyle(.white.opacity(0.4))
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(.white.opacity(0.08))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
        }
        .ignoresSafeArea(edges: .top)
        .defaultScrollAnchor(.top)
        .tint(SomniaColors.accentBright)
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image("Wordmark")
                .resizable()
                .scaledToFit()
                .frame(width: 76)
                .opacity(0.5)
            Text("No sessions yet")
                .font(SomniaFont.bold(14))
                .foregroundStyle(.white.opacity(0.7))
                .padding(.top, 6)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onClose)
    }

    private func dateTitle(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: date)
    }
}

#Preview {
    HistoryView(store: SessionHistoryStore(), onClose: {})
}
