import Foundation
import CoreMotion

/// Raw wrist motion — the one signal here that's genuinely live and
/// continuous (up to 100Hz), unlike heart rate (~once per few seconds) or
/// HRV (once every few minutes). If the wrist rests on the chest, user
/// acceleration's vertical component is a direct proxy for chest rise/fall
/// — this is the actual candidate signal for a closed-loop breathing read,
/// not the heart-rate data, which is a proxy of a proxy.
@MainActor
final class MotionManager: ObservableObject {
    @Published private(set) var accel: (x: Double, y: Double, z: Double) = (0, 0, 0)
    @Published private(set) var userAccel: (x: Double, y: Double, z: Double) = (0, 0, 0)
    @Published private(set) var rotationRate: (x: Double, y: Double, z: Double) = (0, 0, 0)
    @Published private(set) var isAvailable: Bool = false

    private let motionManager = CMMotionManager()
    /// Enough resolution to see the breathing-rate band (0.1–0.3Hz) clearly
    /// on screen without redrawing faster than a watch display usefully can.
    private let updateInterval: TimeInterval = 1.0 / 20.0

    func start() {
        isAvailable = motionManager.isDeviceMotionAvailable
        guard isAvailable else { return }

        motionManager.deviceMotionUpdateInterval = updateInterval
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let motion else { return }
            self.userAccel = (motion.userAcceleration.x, motion.userAcceleration.y, motion.userAcceleration.z)
            self.rotationRate = (motion.rotationRate.x, motion.rotationRate.y, motion.rotationRate.z)
            // Raw accelerometer = user acceleration + gravity, reconstructed
            // from device motion rather than run as a second concurrent
            // stream (CoreMotion doesn't love multiple simultaneous raw
            // subscriptions on watchOS).
            self.accel = (
                motion.userAcceleration.x + motion.gravity.x,
                motion.userAcceleration.y + motion.gravity.y,
                motion.userAcceleration.z + motion.gravity.z
            )
        }
    }

    func stop() {
        motionManager.stopDeviceMotionUpdates()
    }
}
