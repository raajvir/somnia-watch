import Foundation
import HealthKit

/// Runs a `HKWorkoutSession` for the duration of a breathing session so we
/// can read live heart rate samples from the watch's sensor.
///
/// Degrades gracefully: if HealthKit isn't available, authorization is
/// denied, or anything else goes wrong, `latestHeartRate`/`averageHeartRate`
/// simply stay `nil` and the rest of the app carries on (the UI shows "--").
@MainActor
final class WorkoutManager: NSObject, ObservableObject {
    @Published private(set) var latestHeartRate: Double?
    @Published private(set) var averageHeartRate: Double?
    @Published private(set) var minHeartRate: Double?
    @Published private(set) var maxHeartRate: Double?
    @Published private(set) var firstHeartRate: Double?
    @Published private(set) var heartRateSampleCount: Int = 0
    @Published private(set) var isAuthorized: Bool = false

    /// Heart rate variability (SDNN, ms) — watchOS computes this periodically
    /// (roughly every 1–5 min) from beat-to-beat timing, not continuously.
    /// There is no live per-beat R-R interval API available to third-party
    /// apps; SDNN samples via HealthKit are the finest-grained cardiac signal
    /// we can actually read.
    @Published private(set) var latestHRV: Double?
    @Published private(set) var hrvSampleCount: Int = 0

    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var hrvQuery: HKAnchoredObjectQuery?
    private var sessionStartDate: Date?

    private var heartRateSamples: [Double] = []

    private var heartRateType: HKQuantityType? {
        HKObjectType.quantityType(forIdentifier: .heartRate)
    }

    private var hrvType: HKQuantityType? {
        HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)
    }

    /// Requests read authorization for heart rate. Safe to call multiple
    /// times; safe to ignore the result (session start will simply no-op
    /// heart rate readings if this fails).
    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable(), let heartRateType, let hrvType else {
            isAuthorized = false
            return
        }

        do {
            try await healthStore.requestAuthorization(toShare: [], read: [heartRateType, hrvType])
            isAuthorized = true
        } catch {
            isAuthorized = false
        }
    }

    /// Starts a mind-and-body workout session so heart rate samples flow in.
    /// No-ops (leaving heart rate as "--") if HealthKit is unavailable.
    func start() {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        latestHeartRate = nil
        averageHeartRate = nil
        minHeartRate = nil
        maxHeartRate = nil
        firstHeartRate = nil
        heartRateSampleCount = 0
        heartRateSamples = []
        latestHRV = nil
        hrvSampleCount = 0

        let sessionStartDate = Date()
        self.sessionStartDate = sessionStartDate
        startHRVQuery(after: sessionStartDate)

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .mindAndBody
        configuration.locationType = .unknown

        do {
            let session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            let builder = session.associatedWorkoutBuilder()
            builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)

            session.delegate = self
            builder.delegate = self

            self.session = session
            self.builder = builder

            session.startActivity(with: sessionStartDate)
            builder.beginCollection(withStart: sessionStartDate) { _, _ in
                // Nothing to do; live samples arrive via the delegate callback.
            }
        } catch {
            session = nil
            builder = nil
        }
    }

    /// Ends the workout session, if one is running.
    func stop() {
        stopHRVQuery()

        guard let session, let builder else { return }

        let endDate = Date()
        session.end()
        builder.endCollection(withEnd: endDate) { [weak self] _, _ in
            builder.finishWorkout { _, _ in }
            Task { @MainActor in
                self?.session = nil
                self?.builder = nil
            }
        }
    }

    fileprivate func handleHeartRateSample(_ value: Double) {
        if firstHeartRate == nil { firstHeartRate = value }
        latestHeartRate = value
        heartRateSamples.append(value)
        heartRateSampleCount = heartRateSamples.count
        averageHeartRate = heartRateSamples.reduce(0, +) / Double(heartRateSamples.count)
        minHeartRate = min(minHeartRate ?? value, value)
        maxHeartRate = max(maxHeartRate ?? value, value)
    }

    /// HealthKit writes SDNN samples opportunistically (not on a fixed
    /// schedule) — an anchored query with `updateHandler` is how we hear
    /// about each new one as it lands, for the duration of the session.
    private func startHRVQuery(after startDate: Date) {
        guard let hrvType else { return }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: nil, options: .strictStartDate)

        let handleSamples: (HKAnchoredObjectQuery, [HKSample]?, [HKDeletedObject]?, HKQueryAnchor?, Error?) -> Void = { [weak self] _, samples, _, _, _ in
            guard let self, let quantitySamples = samples as? [HKQuantitySample], !quantitySamples.isEmpty else { return }
            let unit = HKUnit.secondUnit(with: .milli)
            Task { @MainActor in
                for sample in quantitySamples.sorted(by: { $0.startDate < $1.startDate }) {
                    self.latestHRV = sample.quantity.doubleValue(for: unit)
                    self.hrvSampleCount += 1
                }
            }
        }

        let query = HKAnchoredObjectQuery(
            type: hrvType, predicate: predicate, anchor: nil, limit: HKObjectQueryNoLimit,
            resultsHandler: handleSamples
        )
        query.updateHandler = handleSamples

        hrvQuery = query
        healthStore.execute(query)
    }

    private func stopHRVQuery() {
        if let hrvQuery {
            healthStore.stop(hrvQuery)
        }
        hrvQuery = nil
    }
}

extension WorkoutManager: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        // No state-specific handling needed; start()/stop() drive the flow.
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        // Degrade gracefully — the session/view keeps running without HR.
    }
}

extension WorkoutManager: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        guard collectedTypes.contains(where: { $0.identifier == HKQuantityTypeIdentifier.heartRate.rawValue }) else {
            return
        }
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else { return }
        guard let statistics = workoutBuilder.statistics(for: heartRateType) else { return }

        let unit = HKUnit.count().unitDivided(by: .minute())
        guard let value = statistics.mostRecentQuantity()?.doubleValue(for: unit) else { return }

        Task { @MainActor [weak self] in
            self?.handleHeartRateSample(value)
        }
    }

    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        // No workout events (e.g. laps/pauses) to handle.
    }
}
