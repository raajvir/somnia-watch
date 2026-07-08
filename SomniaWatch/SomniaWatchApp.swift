import SwiftUI

/// Brand palette, shared by all screens.
enum SomniaColors {
    static let background = Color(red: 0.03, green: 0.04, blue: 0.09)
    static let accent = Color(red: 0.42, green: 0.58, blue: 0.84)
    static let accentBright = Color(red: 0.36, green: 0.44, blue: 0.95)
    static let text = Color.white

    /// Radial gradient used for the breathing bubble: near-white core easing
    /// out to the soft blue accent.
    static let bubbleCore = Color(red: 0.82, green: 0.90, blue: 1.0)
    static let bubbleEdge = Color(red: 0.40, green: 0.56, blue: 0.86)
}

/// Custom-session bounds (minutes), driven by the Digital Crown.
enum SessionBounds {
    static let minMinutes = 6
    static let maxMinutes = 24
    static let defaultMinutes = 8
}

/// Simple state-driven navigation: which screen is currently shown.
/// No navigation stack/router needed for a flow this small.
enum AppScreen: Equatable {
    case home
    case session(minutes: Int)
    case summary(SessionRecord)
    case history
    case liveData
}

/// A sample record used only to preview the summary/history screens directly
/// from a launch argument, without needing to run a full session first.
private let previewRecord = SessionRecord(
    startedAt: Date().addingTimeInterval(-8 * 60), completedAt: Date(),
    actualMinutes: 8, totalBreaths: 62,
    averageHeartRate: 64, minHeartRate: 52, maxHeartRate: 79,
    firstHeartRate: 74, lastHeartRate: 55, heartRateSampleCount: 471
)

@main
struct SomniaWatchApp: App {
    // Launch args for automated UI verification: jump straight to a screen.
    @State private var screen: AppScreen = {
        let args = CommandLine.arguments
        if args.contains("-autostart") { return .session(minutes: 8) }
        if args.contains("-showsummary") { return .summary(previewRecord) }
        if args.contains("-showhistory") { return .history }
        if args.contains("-showlivedata") { return .liveData }
        return .home
    }()
    @StateObject private var sessionController = SessionController()
    @StateObject private var workoutManager = WorkoutManager()
    @StateObject private var historyStore = SessionHistoryStore()

    private var startWithPicker: Bool {
        CommandLine.arguments.contains("-showpicker")
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                SomniaColors.background.ignoresSafeArea()

                switch screen {
                case .home:
                    HomeView(startWithPicker: startWithPicker) { minutes in
                        screen = .session(minutes: minutes)
                    } onHistory: {
                        screen = .history
                    } onLiveData: {
                        screen = .liveData
                    }
                case .session(let minutes):
                    SessionView(
                        minutes: minutes,
                        controller: sessionController,
                        workoutManager: workoutManager,
                        onFinish: { record in
                            historyStore.add(record)
                            screen = .summary(record)
                        }
                    )
                case .summary(let record):
                    SummaryView(record: record) {
                        screen = .home
                    }
                case .history:
                    HistoryView(store: historyStore) {
                        screen = .home
                    }
                case .liveData:
                    LiveDataView {
                        screen = .home
                    }
                }
            }
            .onAppear {
                if CommandLine.arguments.contains("-showhistory"), historyStore.records.isEmpty {
                    historyStore.add(previewRecord)
                    historyStore.add(SessionRecord(
                        startedAt: Date().addingTimeInterval(-86400 - 12 * 60),
                        completedAt: Date().addingTimeInterval(-86400), actualMinutes: 12,
                        totalBreaths: 84, averageHeartRate: 58, minHeartRate: 49, maxHeartRate: 71
                    ))
                }
            }
        }
    }
}
