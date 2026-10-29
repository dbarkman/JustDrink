//
// TiltSpring.swift
// JustDrink
//

import Foundation

// Water sloshing in the glass, as a damped spring: the water's angle is pulled toward level with gravity,
// so it lags behind a quick tilt, overshoots a little and settles
struct TiltSpring {
    // About 1.2 swings a second, damped so it settles in about a second
    static let stiffness = 60.0
    static let damping = 7.0

    // Radians the water is turned on screen, clockwise positive. Never wrapped, so it can't jump at half a turn.
    private(set) var angle: Double = 0
    private(set) var velocity: Double = 0
    // 0 to 1: how hard the water is moving, used to make the waves bigger while it sloshes
    private(set) var swing: Double = 0

    // The on-screen turn that keeps the water level, from gravity in the device's frame (x right, y up),
    // and how far to trust it: a phone lying flat has almost no gravity across the screen
    static func level(gravityX x: Double, gravityY y: Double) -> (angle: Double, weight: Double) {
        let across = (x * x + y * y).squareRoot()
        let weight = min(max((across - 0.15) / 0.25, 0), 1)
        return (-atan2(x, -y), weight)
    }

    mutating func step(toward target: Double, weight: Double, dt: Double) {
        // Skip gaps (a paused screen) instead of integrating one huge step
        let dt = min(max(dt, 0), 0.05)
        // The shortest way round to the target, pulled less hard as the phone lies flatter
        let offset = remainder(target - angle, 2 * .pi) * weight
        let acceleration = TiltSpring.stiffness * offset - TiltSpring.damping * velocity
        velocity += acceleration * dt
        angle += velocity * dt
        let wanted = min(abs(velocity) / 4, 1)
        swing += (wanted - swing) * min(dt * 6, 1)
    }
}
