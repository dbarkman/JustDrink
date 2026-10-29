//
// WaterTilt.swift
// JustDrink
//

import CoreMotion

// Feeds the phone's gravity reading into a TiltSpring while the glass is on screen.
// Device motion needs no permission prompt; updates arrive on the main queue.
final class WaterTilt {
    private let manager = CMMotionManager()
    private var spring = TiltSpring()
    private var lastTimestamp: TimeInterval?

    var angle: Double { spring.angle }
    var swing: Double { spring.swing }

    func start() {
        guard manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 60
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let motion else { return }
            let level = TiltSpring.level(gravityX: motion.gravity.x, gravityY: motion.gravity.y)
            let dt = lastTimestamp.map { motion.timestamp - $0 } ?? 0
            lastTimestamp = motion.timestamp
            spring.step(toward: level.angle, weight: level.weight, dt: dt)
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
        lastTimestamp = nil
    }
}
