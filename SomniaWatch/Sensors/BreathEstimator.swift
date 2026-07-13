import CoreMotion

/// Estimates the wearer's breathing rate from slow wrist-tilt oscillation.
/// With the watch arm resting on the chest/belly (how people lie in bed),
/// breathing rocks the wrist at 0.09-0.2 Hz. That motion lives in the
/// GRAVITY vector's slow drift — CoreMotion high-pass-filters
/// userAcceleration, which would destroy a 0.1 Hz signal, so gravity is
/// the right channel. Autocorrelation over a sliding window yields both a
/// period estimate and a built-in confidence (the peak's strength), so the
/// caller always knows when the signal is unusable (arm position, movement).
@MainActor
final class BreathEstimator: ObservableObject {
    /// Latest estimate, breaths per minute. nil until the buffer fills or
    /// when confidence is below `minConfidence`.
    @Published private(set) var estimatedBpm: Double?
    /// 0...1 strength of the autocorrelation peak behind the estimate.
    @Published private(set) var confidence: Double = 0
    /// Fraction of completed estimation windows so far that met
    /// `minConfidence` — a session-level "how usable was the signal" figure.
    @Published private(set) var coverage: Double = 0

    static let minConfidence: Double = 0.3

    private let motion = CMMotionManager()
    private let sampleRate: Double = 20
    private let windowSeconds: Double = 45
    private var buffer: [(x: Double, y: Double, z: Double)] = []
    private var timer: Timer?
    private var windowsTotal = 0
    private var windowsConfident = 0

    func start() {
        guard motion.isDeviceMotionAvailable else { return }
        buffer.removeAll()
        windowsTotal = 0; windowsConfident = 0
        estimatedBpm = nil; confidence = 0; coverage = 0
        motion.deviceMotionUpdateInterval = 1.0 / sampleRate
        motion.startDeviceMotionUpdates(to: .main) { [weak self] dm, _ in
            guard let self, let g = dm?.gravity else { return }
            self.buffer.append((g.x, g.y, g.z))
            let cap = Int(self.windowSeconds * self.sampleRate)
            if self.buffer.count > cap { self.buffer.removeFirst(self.buffer.count - cap) }
        }
        let t = Timer(timeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.estimate() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func stop() {
        motion.stopDeviceMotionUpdates()
        timer?.invalidate(); timer = nil
    }

    private func estimate() {
        // Need >= 30s of data before trusting anything.
        guard buffer.count >= Int(30 * sampleRate) else { return }
        let axes = [buffer.map(\.x), buffer.map(\.y), buffer.map(\.z)]
        var best: (bpm: Double, conf: Double) = (0, 0)
        for axis in axes {
            if let r = Self.autocorrelationEstimate(axis, sampleRate: sampleRate), r.conf > best.conf {
                best = r
            }
        }
        windowsTotal += 1
        if best.conf >= Self.minConfidence {
            windowsConfident += 1
            estimatedBpm = best.bpm
            confidence = best.conf
        } else {
            estimatedBpm = nil
            confidence = best.conf
        }
        coverage = windowsTotal > 0 ? Double(windowsConfident) / Double(windowsTotal) : 0
    }

    /// Pure estimation core, exposed for testing. Detrends the series, then
    /// scans normalized autocorrelation over lags spanning 20 down to 5 bpm
    /// (3s...12s) and returns the strongest peak as (bpm, confidence).
    static func autocorrelationEstimate(_ series: [Double], sampleRate: Double) -> (bpm: Double, conf: Double)? {
        let n = series.count
        guard n > Int(12 * sampleRate) else { return nil }
        let mean = series.reduce(0, +) / Double(n)
        let x = series.map { $0 - mean }
        let energy = x.reduce(0) { $0 + $1 * $1 }
        guard energy > 0 else { return nil }
        let minLag = Int(3.0 * sampleRate), maxLag = min(Int(12.0 * sampleRate), n - 1)
        var bestLag = 0; var bestR = 0.0
        for lag in minLag...maxLag {
            var s = 0.0
            for i in 0..<(n - lag) { s += x[i] * x[i + lag] }
            let r = s / energy
            if r > bestR { bestR = r; bestLag = lag }
        }
        guard bestLag > 0 else { return nil }
        return (bpm: 60.0 * sampleRate / Double(bestLag), conf: max(0, min(1, bestR)))
    }
}
