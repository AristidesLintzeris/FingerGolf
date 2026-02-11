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

        let dx = ballNode.position.x - holePosition.x
        let dz = ballNode.position.z - holePosition.z
        let distance = sqrt(dx * dx + dz * dz)

        return speed < captureVelocityThreshold && distance < captureDistanceThreshold
    }
}
