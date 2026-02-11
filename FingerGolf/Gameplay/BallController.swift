import SceneKit

class BallController {

    enum BallState {
        case atRest
        case moving
        case inHole
    }

    let ballNode: SCNNode
    private(set) var state: BallState = .atRest
    private var lastRestPosition: SCNVector3 = SCNVector3Zero

    init(color: String = "red") {
        let modelName = "ball-\(color)"
        if let loaded = AssetCatalog.shared.loadPiece(named: modelName) {
            ballNode = loaded
        } else {
            // Fallback: create a simple sphere
            let sphere = SCNSphere(radius: 0.035)
            sphere.firstMaterial?.diffuse.contents = UIColor.red
            ballNode = SCNNode(geometry: sphere)
        }
        ballNode.name = "golf_ball"
    }

    // MARK: - Placement

    func placeBall(at position: SCNVector3) {
        ballNode.position = SCNVector3(position.x, 0.065, position.z)
        ballNode.physicsBody?.velocity = SCNVector3Zero
        ballNode.physicsBody?.angularVelocity = SCNVector4Zero
        ballNode.isHidden = false
        lastRestPosition = ballNode.position
        state = .atRest
    }

    // MARK: - Swing

    func applyForce(direction: SCNVector3, power: CGFloat) {
        guard state == .atRest else { return }

        let force = SCNVector3(
            direction.x * Float(power),
            0.02,  // slight upward for ramps
            direction.z * Float(power)
        )
        ballNode.physicsBody?.applyForce(force, asImpulse: true)
        state = .moving
    }

    // MARK: - State Checking

    var isAtRest: Bool {
        guard let body = ballNode.physicsBody else { return true }
        let v = body.velocity
        let speed = sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
        let av = body.angularVelocity
        let angularSpeed = sqrt(av.x * av.x + av.y * av.y + av.z * av.z)
        return speed < 0.01 && angularSpeed < 0.05
    }

    func updateState() {
        switch state {
        case .moving:
            if isAtRest {
                state = .atRest
                lastRestPosition = ballNode.position
            }
        default:
            break
        }
    }

    // MARK: - Hole

    func captureInHole(holePosition: SCNVector3) {
        state = .inHole
        ballNode.physicsBody?.velocity = SCNVector3Zero
        ballNode.physicsBody?.angularVelocity = SCNVector4Zero
        ballNode.physicsBody?.isAffectedByGravity = false
        ballNode.physicsBody?.type = .kinematic

        // Animate ball into hole
        let moveToHole = SCNAction.move(
            to: SCNVector3(holePosition.x, 0.02, holePosition.z),
            duration: 0.2
        )
        let shrink = SCNAction.scale(to: 0.4, duration: 0.3)
        let drop = SCNAction.moveBy(x: 0, y: -0.05, z: 0, duration: 0.2)
        let fadeOut = SCNAction.fadeOut(duration: 0.15)

        let captureSequence = SCNAction.sequence([
            moveToHole,
            SCNAction.group([shrink, drop]),
            fadeOut
        ])

        ballNode.runAction(captureSequence)
    }

    // MARK: - Reset

    func resetToLastPosition() {
        ballNode.physicsBody?.velocity = SCNVector3Zero
        ballNode.physicsBody?.angularVelocity = SCNVector4Zero
        ballNode.position = lastRestPosition
        ballNode.isHidden = false
        ballNode.opacity = 1.0
        ballNode.scale = SCNVector3(1, 1, 1)
        ballNode.physicsBody?.isAffectedByGravity = true
        ballNode.physicsBody?.type = .dynamic
        state = .atRest
    }
}
