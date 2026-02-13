import SceneKit

class HoleDetector {

    private let captureVelocityThreshold: Float
    private let captureDistanceThreshold: Float
    private var holePosition: SCNVector3 = SCNVector3Zero

    init(settings: GameSettings) {
        self.captureVelocityThreshold = settings.holeCaptureVelocityThreshold
        self.captureDistanceThreshold = settings.holeCaptureDistanceThreshold
    }

    func setHolePosition(_ position: SCNVector3) {
        holePosition = SCNVector3(position.x, 0, position.z)
    }

    func shouldCaptureBall(_ ballNode: SCNNode) -> Bool {
        guard let body = ballNode.physicsBody else { return false }

        let v = body.velocity
        let speed = sqrt(v.x * v.x + v.y * v.y + v.z * v.z)

        // Use presentation position (actual physics position, not manually-set position)
        let ballPos = ballNode.presentation.position
        let dx = ballPos.x - holePosition.x
        let dz = ballPos.z - holePosition.z
        let distance = sqrt(dx * dx + dz * dz)

        // Enhanced capture: very close to center allows faster balls (hole-in-one support)
        let enhancedCenterRadius: Float = 0.025
        let enhancedSpeedLimit: Float = 1.5
        if distance < enhancedCenterRadius && speed < enhancedSpeedLimit {
            return true
        }

        return speed < captureVelocityThreshold && distance < captureDistanceThreshold
    }
}
