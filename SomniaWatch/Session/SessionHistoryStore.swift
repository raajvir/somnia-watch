import Foundation

/// A completed session's record, as shown on the summary screen and kept in
/// history. All fields are honest measurements or values derived from the
/// commanded ramp — nothing here implies sensing we don't do (no breathing
/// rate detection yet; that's the closed-loop roadmap work).
struct SessionRecord: Codable, Identifiable, Equatable {
    let id: UUID
    let startedAt: Date
    let completedAt: Date
    let actualMinutes: Int
    let totalBreaths: Int
    let averageHeartRate: Double?
    let minHeartRate: Double?
    let maxHeartRate: Double?
    /// The first and last heart-rate samples HealthKit reported this session
    /// — real measurements, not an estimate of breathing rate.
    let firstHeartRate: Double?
    let lastHeartRate: Double?
    let heartRateSampleCount: Int
    /// The session's originally scheduled length in minutes (before any
    /// dynamic extension). Optional — absent on records written before this
    /// field existed.
    let targetMinutes: Int?
    /// Extra seconds appended by dynamic extension, beyond `targetMinutes`.
    /// Optional for the same reason, and 0/nil for fixed-length sessions.
    let extendedSeconds: Int?
    /// Fraction of the session's breath-rate estimation windows that had a
    /// usable motion signal. Only meaningful for dynamic sessions; recorded
    /// regardless since it's harmless for fixed ones.
    let breathSignalCoverage: Double?
    /// Commanded breathing rate at the start/end of the session (bpm), from
    /// `BreathingConfig` — not a measured rate.
    let startPaceBpm: Double
    let endPaceBpm: Double

    init(
        startedAt: Date,
        completedAt: Date,
        actualMinutes: Int,
        totalBreaths: Int,
        averageHeartRate: Double?,
        minHeartRate: Double?,
        maxHeartRate: Double?,
        firstHeartRate: Double? = nil,
        lastHeartRate: Double? = nil,
        heartRateSampleCount: Int = 0,
        targetMinutes: Int? = nil,
        extendedSeconds: Int? = nil,
        breathSignalCoverage: Double? = nil,
        startPaceBpm: Double = 60 / BreathingConfig.startBreathDuration,
        endPaceBpm: Double = 60 / BreathingConfig.endBreathDuration
    ) {
        self.id = UUID()
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.actualMinutes = actualMinutes
        self.totalBreaths = totalBreaths
        self.averageHeartRate = averageHeartRate
        self.minHeartRate = minHeartRate
        self.maxHeartRate = maxHeartRate
        self.firstHeartRate = firstHeartRate
        self.lastHeartRate = lastHeartRate
        self.heartRateSampleCount = heartRateSampleCount
        self.targetMinutes = targetMinutes
        self.extendedSeconds = extendedSeconds
        self.breathSignalCoverage = breathSignalCoverage
        self.startPaceBpm = startPaceBpm
        self.endPaceBpm = endPaceBpm
    }
}

/// Persists completed sessions to `UserDefaults` as JSON. Small, infrequent
/// writes — no need for a database on a watch-only history list.
@MainActor
final class SessionHistoryStore: ObservableObject {
    @Published private(set) var records: [SessionRecord] = []

    private let defaultsKey = "com.projectsomnia.watch.sessionHistory"
    private let maxStored = 100

    init() {
        load()
    }

    func add(_ record: SessionRecord) {
        records.insert(record, at: 0)
        if records.count > maxStored {
            records = Array(records.prefix(maxStored))
        }
        save()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey) else { return }

        // Decode records individually so one undecodable record (e.g. written
        // by an older build with a different schema) doesn't wipe all history.
        struct FailableRecord: Decodable {
            let record: SessionRecord?
            init(from decoder: Decoder) throws {
                record = try? SessionRecord(from: decoder)
            }
        }

        guard let decoded = try? JSONDecoder().decode([FailableRecord].self, from: data) else { return }
        records = decoded.compactMap(\.record)
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(records) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }
}
