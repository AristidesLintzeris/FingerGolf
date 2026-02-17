import SceneKit

class BallController {

    // MARK: - Shot Configuration

    let maxForce: Float = 5.0
    let forceModifier: Float = 2.0

    // MARK: - Ball State

    private(set) var ballIsStatic: Bool = false
    private(set) var pendingShot: SCNVector3?
    private var graceFrames: Int = 0
    private var restFrameCount: Int = 0

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
    /// Always use this instead of ballNode.position for physics-driven nodes.
    var worldPosition: SCNVector3 {
        ballNode.presentation.position
    }

    // MARK: - Aim Line

    private(set) var aimLineNode: SCNNode?

    // MARK: - Init

    init(color: String = "red") {
        // Golf ball: white sphere with PBR material
        let sphere = SCNSphere(radius: 0.035)
        let mat = SCNMaterial()
        mat.diffuse.contents = UIColor.white
        mat.lightingModel = .physicallyBased
        mat.roughness.contents = NSNumber(value: 0.3)
        mat.metalness.contents = NSNumber(value: 0.1)
        sphere.firstMaterial = mat
        ballNode = SCNNode(geometry: sphere)
        ballNode.name = "golf_ball"

        // Aim ring: torus around ball showing touch zone
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

        // Aim line: flat box that stretches from ball toward finger
        let box = SCNBox(width: 0.012, height: 0.006, length: 1.0, chamferRadius: 0)
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
        // Shift pivot so box extends from Z=0 to Z=+1
        aimLineNode?.pivot = SCNMatrix4MakeTranslation(0, 0, -0.5)
    }

    // MARK: - Placement

    func placeBall(at position: SCNVector3) {
        // Clear any lingering hole-capture animations
        ballNode.removeAllActions()

        // Drop ball from slightly above the play surface (Y=0.146)
        ballNode.position = SCNVector3(position.x, 0.25, position.z)

        ballNode.physicsBody?.velocity = SCNVector3Zero
        ballNode.physicsBody?.angularVelocity = SCNVector4Zero
        ballNode.physicsBody?.type = .dynamic
        ballNode.physicsBody?.isAffectedByGravity = true

        ballNode.isHidden = false
        ballNode.opacity = 1.0
        ballNode.scale = SCNVector3(1, 1, 1)

        // Ball is settling after drop — not ready to play yet
        ballIsStatic = false
        pendingShot = nil
        graceFrames = 40 // ~0.67s at 60fps for ball to settle
        restFrameCount = 0

        areaAffectorNode.isHidden = true
        areaAffectorNode.position = SCNVector3(position.x, 0.15, position.z)
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

        // Direct aim: ball fires toward finger position
        direction = SCNVector3(dx, 0, dz)

        updateAimLine()

        // Visual feedback: ring scales up and turns red with power
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

        aimLineNode.position = ballPos
        aimLineNode.eulerAngles = SCNVector3(0, atan2(dx, dz), 0)
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

    /// Called every frame (60fps). Applies queued shots and detects when ball stops.
    /// Returns true the frame the ball comes to rest.
    @discardableResult
    func checkState() -> Bool {
        // Apply queued shot
        if let impulse = pendingShot {
            pendingShot = nil
            ballIsStatic = false
            restFrameCount = 0
            areaAffectorNode.isHidden = true
            graceFrames = 15

            ballNode.physicsBody?.applyForce(impulse, asImpulse: true)
            return false
        }

        // Grace period: let the ball get moving before checking rest
        if graceFrames > 0 {
            graceFrames -= 1
            return false
        }

        // If ball was declared at rest, check if it started moving again
        // (e.g., gravity pulling it down a slope that friction can't hold)
        if ballIsStatic {
            guard let body = ballNode.physicsBody else { return false }
            let v = body.velocity
            let speed = sqrt(v.x * v.x + v.y * v.y + v.z * v.z)

            if speed > 0.05 {
                // Ball woke up — slope or external force moved it
                ballIsStatic = false
                restFrameCount = 0
                areaAffectorNode.isHidden = true
                graceFrames = 10
            } else {
                // Track any micro-drift so aim ring stays centered
                let pos = worldPosition
                areaAffectorNode.position = SCNVector3(pos.x, pos.y - 0.03, pos.z)
            }
            return false
        }

        // Rest detection: require many consecutive frames at near-zero speed
        // before declaring rest. Physics handles ALL deceleration naturally.
        guard let body = ballNode.physicsBody else { return false }
        let v = body.velocity
        let speed = sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
        let av = body.angularVelocity
        let angularSpeed = sqrt(av.x * av.x + av.y * av.y + av.z * av.z)

        // At speed 0.01 the ball moves ~0.0002 units/frame — invisible
        if speed < 0.01 && angularSpeed < 0.02 {
            restFrameCount += 1
        } else {
            restFrameCount = 0
        }

        // After 30 consecutive frames (~0.5s) of near-zero motion, declare rest.
        // Ball stays dynamic with gravity — on slopes, gravity will re-awaken it.
        if restFrameCount >= 30 {
            ballIsStatic = true

            // Zero residual micro-velocity but keep dynamic + gravity active.
            // On flat ground, normal force counters gravity — ball stays put.
            // On steep slopes, gravity overcomes friction — ball slides naturally.
            body.velocity = SCNVector3Zero
            body.angularVelocity = SCNVector4Zero

            let pos = worldPosition
            ballNode.position = pos

            areaAffectorNode.isHidden = false
            areaAffectorNode.position = SCNVector3(pos.x, pos.y - 0.03, pos.z)
            return true
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

        // Snap to actual physics position
        ballNode.position = worldPosition

        ballNode.physicsBody?.velocity = SCNVector3Zero
        ballNode.physicsBody?.angularVelocity = SCNVector4Zero
        ballNode.physicsBody?.isAffectedByGravity = false
        ballNode.physicsBody?.type = .kinematic

        // Animate ball into the hole:
        // 1. Slide to hole center at the play surface height
        // 2. Shrink + drop below surface
        // 3. Fade out
        let surfaceY: Float = 0.146
        let moveToHole = SCNAction.move(
            to: SCNVector3(holePosition.x, surfaceY, holePosition.z),
            duration: 0.2
        )
        let shrink = SCNAction.scale(to: 0.4, duration: 0.3)
        let drop = SCNAction.moveBy(x: 0, y: -0.08, z: 0, duration: 0.2)
        let fadeOut = SCNAction.fadeOut(duration: 0.15)

        ballNode.runAction(SCNAction.sequence([
            moveToHole,
            SCNAction.group([shrink, drop]),
            fadeOut
        ]))
    }
}
