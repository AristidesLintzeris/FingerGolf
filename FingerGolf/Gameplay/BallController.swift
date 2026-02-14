import SceneKit

/// Ball controller handling physics, aiming, and shot mechanics.
/// Slingshot pull-back: drag away from ball, shot goes opposite direction.
/// Trajectory dots show shot direction and power.
class BallController {

    // MARK: - Shot Configuration

    let maxForce: Float = 5.0
    let forceModifier: Float = 2.0

    // MARK: - Ball State

    private(set) var ballIsStatic: Bool = true
    private(set) var pendingShot: SCNVector3?
    private var shotGraceFrames: Int = 0

    // MARK: - Aiming State

    private(set) var startPos: SCNVector3 = SCNVector3Zero
    private(set) var endPos: SCNVector3 = SCNVector3Zero
    private(set) var force: Float = 0
    private(set) var direction: SCNVector3 = SCNVector3Zero
    private(set) var isAiming: Bool = false

    /// Normalized power 0..1 for UI power bar
    var normalizedPower: Float {
        maxForce > 0 ? force / maxForce : 0
    }

    // MARK: - Nodes

    let ballNode: SCNNode
    let areaAffectorNode: SCNNode

    /// Current world position of the ball (accounts for physics simulation).
    /// SceneKit physics updates `presentation.position`, not `position`.
    var worldPosition: SCNVector3 {
        ballNode.presentation.position
    }

    // MARK: - Aim Line

    private var aimLineNode: SCNNode?

    // MARK: - Init

    init(color: String = "red") {
        // Create procedural sphere (no model loading)
        let sphere = SCNSphere(radius: 0.035)
        let mat = SCNMaterial()
        mat.diffuse.contents = UIColor.white
        mat.lightingModel = .physicallyBased
        mat.roughness.contents = NSNumber(value: 0.3)
        mat.metalness.contents = NSNumber(value: 0.1)
        sphere.firstMaterial = mat
        ballNode = SCNNode(geometry: sphere)
        ballNode.name = "golf_ball"

        // Area affector: ring around ball showing aim zone
        let ring = SCNTorus(ringRadius: 0.22, pipeRadius: 0.005)
        let ringMat = SCNMaterial()
        ringMat.diffuse.contents = UIColor.white.withAlphaComponent(0.4)
        ringMat.lightingModel = .constant
        ringMat.writesToDepthBuffer = false
        ringMat.readsFromDepthBuffer = false // Always visible
        ringMat.isDoubleSided = true
        ring.firstMaterial = ringMat
        areaAffectorNode = SCNNode(geometry: ring)
        areaAffectorNode.name = "area_affector"
        areaAffectorNode.renderingOrder = 90
        areaAffectorNode.isHidden = false

        // Create aim line (cylinder that will be rotated and scaled)
        let cylinder = SCNCylinder(radius: 0.008, height: 1.0)
        let lineMat = SCNMaterial()
        lineMat.diffuse.contents = UIColor.white.withAlphaComponent(0.7)
        lineMat.lightingModel = .constant
        lineMat.writesToDepthBuffer = false
        lineMat.readsFromDepthBuffer = false
        cylinder.firstMaterial = lineMat
        aimLineNode = SCNNode(geometry: cylinder)
        aimLineNode?.name = "aim_line"
        aimLineNode?.isHidden = true
        aimLineNode?.renderingOrder = 95
    }

    // MARK: - Placement

    func placeBall(at position: SCNVector3) {
        ballNode.removeAllActions()

        // Spawn ball at Y=0.07 (safe height for mesh floors)
        // Set to kinematic so it is PERFECTLY still at the start.
        ballNode.position = SCNVector3(position.x, 0.09, position.z)

        ballNode.physicsBody?.velocity = SCNVector3Zero
        ballNode.physicsBody?.angularVelocity = SCNVector4Zero
        ballNode.physicsBody?.type = .kinematic
        ballNode.physicsBody?.isAffectedByGravity = true

        ballNode.isHidden = false
        ballNode.opacity = 1.0
        ballNode.scale = SCNVector3(1, 1, 1)

        ballIsStatic = true
        pendingShot = nil
        shotGraceFrames = 0

        // Position aim ring slightly above floor surface (which is ~0.03)
        areaAffectorNode.isHidden = false
        areaAffectorNode.position = SCNVector3(position.x, 0.04, position.z)

        // Add aim line to scene if not already added
        if let aimLineNode, aimLineNode.parent == nil {
            ballNode.parent?.addChildNode(aimLineNode)
        }
    }

    // MARK: - Aiming (slingshot pull-back)

    func aimBegan(worldPoint: SCNVector3) {
        startPos = worldPosition
        endPos = worldPoint
        isAiming = true
        updateAiming()
    }

    func aimMoved(worldPoint: SCNVector3) {
        guard isAiming else { return }
        endPos = worldPoint
        startPos = worldPosition
        updateAiming()
    }

    func aimEnded() -> SCNVector3? {
        guard isAiming else { return nil }
        isAiming = false
        hideAimLine()

        guard force > 0.02 else {
            resetAim()
            return nil
        }

        let len = sqrt(direction.x * direction.x + direction.z * direction.z)
        guard len > 0.001 else {
            resetAim()
            return nil
        }

        let nx = direction.x / len
        let nz = direction.z / len
        let impulse = SCNVector3(nx * force, 0, nz * force)

        resetAim()
        return impulse
    }

    func cancelAim() {
        resetAim()
    }

    private func updateAiming() {
        let ballPos = worldPosition

        // Calculate direction from ball to finger (where we're aiming)
        let dx = endPos.x - ballPos.x
        let dz = endPos.z - ballPos.z
        let distance = sqrt(dx * dx + dz * dz)
        force = min(distance * forceModifier, maxForce)

        // Shot direction = same as drag direction (direct aim, NOT slingshot)
        direction = SCNVector3(dx, 0, dz)

        updateAimLine()

        // Update aim ring visual feedback (scale and color)
        let power = normalizedPower
        let s = 1.0 + power * 0.5
        areaAffectorNode.scale = SCNVector3(s, 1.0, s)

        // Color transition: White (0 power) -> Red (max power)
        let color = UIColor(red: 1.0, green: CGFloat(1.0 - power), blue: CGFloat(1.0 - power), alpha: 0.6)
        areaAffectorNode.geometry?.firstMaterial?.diffuse.contents = color
    }
    private func resetAim() {
        isAiming = false
        force = 0
        direction = SCNVector3Zero
        startPos = SCNVector3Zero
        endPos = SCNVector3Zero
        hideAimLine()
        areaAffectorNode.scale = SCNVector3(1, 1, 1)
        areaAffectorNode.geometry?.firstMaterial?.diffuse.contents = UIColor.white.withAlphaComponent(0.4)
    }

    // MARK: - Aim Line

    private func updateAimLine() {
        guard force > 0.01 else {
            hideAimLine()
            return
        }

        guard let aimLineNode else { return }

        let ballPos = worldPosition

        // Calculate direction from ball to finger (where we're aiming)
        let dx = endPos.x - ballPos.x
        let dz = endPos.z - ballPos.z
        let lineLength = sqrt(dx * dx + dz * dz)

        guard lineLength > 0.001 else {
            hideAimLine()
            return
        }

        let nx = dx / lineLength
        let nz = dz / lineLength

        // ANCHOR LINE AT BALL: Cylinder center is at midpoint between ball and finger
        // This makes the line appear to start at ball and end at finger
        let offsetX = ballPos.x + nx * lineLength * 0.5
        let offsetZ = ballPos.z + nz * lineLength * 0.5
        // Position line at ball's Y position (slightly above ground)
        aimLineNode.position = SCNVector3(offsetX, ballPos.y, offsetZ)

        // Rotate cylinder to point from ball to finger
        // Cylinder's default orientation is vertical (along Y-axis)
        // We need to rotate it to horizontal and point in direction
        let angle = atan2(nx, nz)
        aimLineNode.eulerAngles = SCNVector3(Float.pi / 2, 0, -angle)

        // Scale cylinder height to match distance from ball to finger
        aimLineNode.scale = SCNVector3(1, lineLength, 1)

        aimLineNode.isHidden = false
    }

    private func hideAimLine() {
        aimLineNode?.isHidden = true
    }

    // MARK: - Shoot

    func queueShot(impulse: SCNVector3) {
        guard ballIsStatic else { return }
        pendingShot = impulse
    }

    /// Called each frame. Applies queued shots and checks ball state.
    /// Returns true if ball just became static (shot completed).
    @discardableResult
    func checkState() -> Bool {
        // Apply queued shot
        if let impulse = pendingShot {
            pendingShot = nil
            ballIsStatic = false
            areaAffectorNode.isHidden = true
            shotGraceFrames = 20  // Longer grace period to let ball get rolling

            // Activate physics: switch from kinematic to dynamic, enable gravity
            ballNode.physicsBody?.type = .dynamic
            ballNode.physicsBody?.isAffectedByGravity = true
            ballNode.physicsBody?.applyForce(impulse, asImpulse: true)
            return false
        }

        // Grace period: let physics engine process the impulse
        if shotGraceFrames > 0 {
            shotGraceFrames -= 1
            return false
        }

        // Check if ball has come to rest
        if !ballIsStatic {
            guard let body = ballNode.physicsBody else { return false }
            let v = body.velocity
            let speed = sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
            let av = body.angularVelocity
            let angularSpeed = sqrt(av.x * av.x + av.y * av.y + av.z * av.z)

            // Lower threshold - only stop when truly at rest
            if speed < 0.01 && angularSpeed < 0.02 {
                ballIsStatic = true
                body.velocity = SCNVector3Zero
                body.angularVelocity = SCNVector4Zero

                // Freeze in place to prevent physics jitter/sliding on slopes
                body.isAffectedByGravity = false
                body.type = .kinematic
                
                let pos = worldPosition
                ballNode.position = pos
                areaAffectorNode.isHidden = false
                // Position ring slightly above the contact point (approx 0.035 below center)
                areaAffectorNode.position = SCNVector3(pos.x, pos.y - 0.03, pos.z)
                return true
            }
        }
        return false
    }

    // MARK: - Fall Detection

    var hasFallenOff: Bool {
        worldPosition.y < -1.0
    }

    // MARK: - Hole Capture

    func captureInHole(holePosition: SCNVector3) {
        ballIsStatic = true
        areaAffectorNode.isHidden = true

        ballNode.position = worldPosition

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
