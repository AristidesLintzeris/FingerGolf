import Foundation

class GameSettings {

    enum BarrierMode {
        case none       // ball can fly off course
        case barrier    // invisible walls keep ball in, ripple effect on hit
    }

    var barrierMode: BarrierMode = .barrier
    var swingSensitivity: CGFloat = 1.0
    var maxSwingPower: CGFloat = 15.0
    var ballAtRestThreshold: Float = 0.01
    var holeCaptureVelocityThreshold: Float = 0.5
    var holeCaptureDistanceThreshold: Float = 0.05
    var handLostTimeout: TimeInterval = 0.5
}
