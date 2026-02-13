import SceneKit

/// Ball controller matching Unity BallControl.cs behavior:
/// - Area affector disc (visible when ball is shootable)
/// - ballIsStatic detection via velocity threshold
/// - canShoot flag gated in physics update
/// - Fall detection when ball leaves course
class BallController {

    // MARK: - State

    private(set) var ballIsStatic: Bool = true
    private(set) var pendingShot: SCNVector3?

    // MARK: - Nodes

    let ballNode: SCNNode
    let areaAffectorNode: SCNNode  // Flat disc showing ball is ready to hit

    // MARK: - Init

    init(color: String = "red") {
        let modelName = "ball-\(color)"
        if let loaded = AssetCatalog.shared.loadPiece(named: modelName) {
            ballNode = loaded
        } else {
            let sphere = SCNSphere(radius: 0.035)
            let mat = SCNMaterial()
            mat.diffuse.contents = UIColor.white
            mat.lightingModel = .physicallyBased
            mat.roughness.contents = NSNumber(value: 0.3)
            sphere.firstMaterial = mat
            ballNode = SCNNode(geometry: sphere)
        }
        ballNode.name = "golf_ball"

        // Area affector: flat transparent disc around ball
        let disc = SCNCylinder(radius: 0.25, height: 0.002)
        let discMat = SCNMaterial()
        discMat.diffuse.contents = UIColor.white.withAlphaComponent(0.25)
        discMat.lightingModel = .constant
        discMat.writesToDepthBuffer = false
        discMat.isDoubleSided = true
        disc.firstMaterial = discMat
        areaAffectorNode = SCNNode(geometry: disc)
        areaAffectorNode.name = "area_affector"
        areaAffectorNode.renderingOrder = 90
        areaAffectorNode.isHidden = false
    }

    // MARK: - Placement

    func placeBall(at position: SCNVector3) {
        // Spawn above surface so gravity settles the ball onto the floor
        ballNode.position = SCNVector3(position.x, 0.15, position.z)
        ballNode.physicsBody?.velocity = SCNVector3Zero
        ballNode.physicsBody?.angularVelocity = SCNVector4Zero
        ballNode.isHidden = false
        ballNode.opacity = 1.0
        ballNode.scale = SCNVector3(1, 1, 1)
        ballNode.physicsBody?.isAffectedByGravity = true
        ballNode.physicsBody?.type = .dynamic
        ballIsStatic = true
        pendingShot = nil

        areaAffectorNode.position = SCNVector3(position.x, 0.005, position.z)
        areaAffectorNode.isHidden = false
    }

    // MARK: - Shoot

    /// Queue a shot impulse. Applied on next checkState call (like Unity FixedUpdate).
    func queueShot(impulse: SCNVector3) {
        guard ballIsStatic else { return }
        pendingShot = impulse
    }

    /// Called each frame. If a shot is queued, apply it. Then check if ball has stopped.
    /// Returns true if ball just became static (shot completed).
    @discardableResult
    func checkState() -> Bool {
        // Apply queued shot
        if let impulse = pendingShot {
            pendingShot = nil
            ballIsStatic = false
            areaAffectorNode.isHidden = true
            ballNode.physicsBody?.applyForce(impulse, asImpulse: true)
            return false
        }

        // Check if ball has come to rest
        if !ballIsStatic {
            guard let body = ballNode.physicsBody else { return false }
            let v = body.velocity
            let speed = sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
            let av = body.angularVelocity
            let angularSpeed = sqrt(av.x * av.x + av.y * av.y + av.z * av.z)

            if speed < 0.02 && angularSpeed < 0.06 {
                ballIsStatic = true
                body.velocity = SCNVector3Zero
                body.angularVelocity = SCNVector4Zero
                areaAffectorNode.isHidden = false
                areaAffectorNode.position = SCNVector3(
                    ballNode.position.x, 0.005, ballNode.position.z
                )
                return true
            }
        }
        return false
    }

    // MARK: - Fall Detection

    var hasFallenOff: Bool {
        ballNode.position.y < -1.0
    }

    // MARK: - Hole Capture

    func captureInHole(holePosition: SCNVector3) {
        ballIsStatic = true
        areaAffectorNode.isHidden = true
        ballNode.physicsBody?.velocity = SCNVector3Zero
        ballNode.physicsBody?.angularVelocity = SCNVector4Zero
        ballNode.physicsBody?.isAffectedByGravity = false
        ballNode.physicsBody?.type = .kinematic

        let moveToHole = SCNAction.move(
            to: SCNVector3(holePosition.x, 0.02, holePosition.z),
            duration: 0.2
        )
        let shrink = SCNAction.scale(to: 0.4, duration: 0.3)
        let drop = SCNAction.moveBy(x: 0, y: -0.05, z: 0, duration: 0.2)
        let fadeOut = SCNAction.fadeOut(duration: 0.15)

        ballNode.runAction(SCNAction.sequence([
            moveToHole,
            SCNAction.group([shrink, drop]),
            fadeOut
        ]))
    }
}
