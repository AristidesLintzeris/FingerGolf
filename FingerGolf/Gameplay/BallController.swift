import SceneKit

class BallController {

    // MARK: - Shot Configuration

    let maxForce: Float = 5.0
    let forceModifier: Float = 2.0

    // MARK: - Ball State

    private(set) var ballIsStatic: Bool = false
    private(set) var pendingShot: SCNVector3?
    private var graceFrames: Int = 0

    // MARK: - Aiming State

    private(set) var startPos: SCNVector3 = SCNVector3Zero
    private(set) var endPos: SCNVector3 = SCNVector3Zero
    private(set) var force: Float = 0
    private(set) var direction: SCNVector3 = SCNVector3Zero
    private(set) var isAiming: Bool = false

    var normalizedPower: Float {
        maxForce > 0 ? force / maxForce : 0
    }

    // MARK: - Nodes

    let ballNode: SCNNode
    let areaAffectorNode: SCNNode

    /// Actual physics-driven position of the ball.
    var worldPosition: SCNVector3 {
        ballNode.presentation.position
    }

    // MARK: - Aim Line (flat box anchored at ball center)

    private var aimLineNode: SCNNode?

    // MARK: - Init

    init(color: String = "red") {
        // Procedural sphere golf ball
        let sphere = SCNSphere(radius: 0.035)
        let mat = SCNMaterial()
        mat.diffuse.contents = UIColor.white
        mat.lightingModel = .physicallyBased
        mat.roughness.contents = NSNumber(value: 0.3)
        mat.metalness.contents = NSNumber(value: 0.1)
        sphere.firstMaterial = mat
        ballNode = SCNNode(geometry: sphere)
        ballNode.name = "golf_ball"

        // Aim ring around ball (shows touch zone)
        let ring = SCNTorus(ringRadius: 0.22, pipeRadius: 0.005)
        let ringMat = SCNMaterial()
        ringMat.diffuse.contents = UIColor.white.withAlphaComponent(0.4)
        ringMat.lightingModel = .constant
        ringMat.writesToDepthBuffer = false
        ringMat.readsFromDepthBuffer = false
        ringMat.isDoubleSided = true
        ring.firstMaterial = ringMat
        areaAffectorNode = SCNNode(geometry: ring)
        areaAffectorNode.name = "area_affector"
        areaAffectorNode.renderingOrder = 90
        areaAffectorNode.isHidden = true

        // Aim line: flat box that extends FROM the ball's position.
        // Using a box lying flat in XZ avoids complex cylinder rotation math.
        // length (Z) = 1.0 base, scaled at runtime to match drag distance.
        let box = SCNBox(width: 0.012, height: 0.002, length: 1.0, chamferRadius: 0)
        let lineMat = SCNMaterial()
        lineMat.diffuse.contents = UIColor.white.withAlphaComponent(0.8)
        lineMat.lightingModel = .constant
        lineMat.writesToDepthBuffer = false
        lineMat.readsFromDepthBuffer = false
        box.firstMaterial = lineMat

        aimLineNode = SCNNode(geometry: box)
        aimLineNode?.name = "aim_line"
        aimLineNode?.isHidden = true
        aimLineNode?.renderingOrder = 95
        // Shift pivot so the box extends from Z=0 to Z=+1 (starts at node origin)
        aimLineNode?.pivot = SCNMatrix4MakeTranslation(0, 0, -0.5)
    }

    // MARK: - Placement

    func placeBall(at position: SCNVector3) {
        ballNode.removeAllActions()

        // Mesh floor is at Y≈0.063. Ball radius is 0.035.
        // Spawn at Y=0.2 so the ball visibly drops onto the course.
        ballNode.position = SCNVector3(position.x, 0.2, position.z)

        ballNode.physicsBody?.velocity = SCNVector3Zero
        ballNode.physicsBody?.angularVelocity = SCNVector4Zero
        ballNode.physicsBody?.type = .dynamic
        ballNode.physicsBody?.isAffectedByGravity = true

        ballNode.isHidden = false
        ballNode.opacity = 1.0
        ballNode.scale = SCNVector3(1, 1, 1)

        // Ball is settling after drop — not ready for play yet
        ballIsStatic = false
        pendingShot = nil
        graceFrames = 40  // ~0.67s at 60fps for ball to settle on mesh

        areaAffectorNode.isHidden = true
        areaAffectorNode.position = SCNVector3(position.x, 0.065, position.z)

        if let aimLineNode, aimLineNode.parent == nil {
            ballNode.parent?.addChildNode(aimLineNode)
        }
    }

    // MARK: - Aiming (direct aim — ball goes where you drag)

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

        let dx = endPos.x - ballPos.x
        let dz = endPos.z - ballPos.z
        let distance = sqrt(dx * dx + dz * dz)
        force = min(distance * forceModifier, maxForce)

        // Direct aim: ball fires toward your finger
        direction = SCNVector3(dx, 0, dz)

        updateAimLine()

        // Visual feedback on aim ring
        let power = normalizedPower
        let s = 1.0 + power * 0.5
        areaAffectorNode.scale = SCNVector3(s, 1.0, s)

        let color = UIColor(
            red: 1.0,
            green: CGFloat(1.0 - power),
            blue: CGFloat(1.0 - power),
            alpha: 0.6
        )
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
        let dx = endPos.x - ballPos.x
        let dz = endPos.z - ballPos.z
        let lineLength = sqrt(dx * dx + dz * dz)

        guard lineLength > 0.001 else {
            hideAimLine()
            return
        }

        // Position at ball center
        aimLineNode.position = ballPos

        // Rotate around Y so the box's +Z axis points from ball toward finger.
        // atan2(dx, dz) = angle from +Z toward +X, which matches a Y-axis rotation.
        aimLineNode.eulerAngles = SCNVector3(0, atan2(dx, dz), 0)

        // Scale Z to stretch the line from ball to finger.
        // The pivot shift makes the box extend from the ball outward.
        aimLineNode.scale = SCNVector3(1, 1, lineLength)

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

    /// Called every frame. Applies queued shots and checks ball state.
    /// Returns true when the ball has just come to rest.
    @discardableResult
    func checkState() -> Bool {
        // Apply queued shot
        if let impulse = pendingShot {
            pendingShot = nil
            ballIsStatic = false
            areaAffectorNode.isHidden = true
            graceFrames = 20

            // Re-activate dynamic physics for the shot
            ballNode.physicsBody?.type = .dynamic
            ballNode.physicsBody?.isAffectedByGravity = true
            ballNode.physicsBody?.applyForce(impulse, asImpulse: true)
            return false
        }

        // Grace period — let the ball get moving before checking rest
        if graceFrames > 0 {
            graceFrames -= 1
            return false
        }

        // Detect ball at rest
        if !ballIsStatic {
            guard let body = ballNode.physicsBody else { return false }
            let v = body.velocity
            let speed = sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
            let av = body.angularVelocity
            let angularSpeed = sqrt(av.x * av.x + av.y * av.y + av.z * av.z)

            if speed < 0.01 && angularSpeed < 0.02 {
                ballIsStatic = true
                body.velocity = SCNVector3Zero
                body.angularVelocity = SCNVector4Zero

                // Freeze ball to prevent jitter/sliding on slopes
                body.isAffectedByGravity = false
                body.type = .kinematic

                let pos = worldPosition
                ballNode.position = pos

                // Show aim ring at ball's resting position
                areaAffectorNode.isHidden = false
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

        // Animate into hole — floor surface is at Y≈0.063
        let moveToHole = SCNAction.move(
            to: SCNVector3(holePosition.x, 0.063, holePosition.z),
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
