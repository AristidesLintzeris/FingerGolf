import SceneKit

/// Ball controller handling physics, aiming, and shot mechanics.
/// Slingshot pull-back: drag away from ball, shot goes opposite direction.
/// Trajectory dots show shot direction and power.
class BallController {

    // MARK: - Shot Configuration

    let maxForce: Float = 1.0
    let forceModifier: Float = 0.5

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

    // MARK: - Trajectory Dots

    private let trajectoryDotCount = 10
    private var trajectoryDots: [SCNNode] = []
    private let trajectoryContainer = SCNNode()

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

        // Area affector: ring around ball showing aim zone
        let ring = SCNTorus(ringRadius: 0.2, pipeRadius: 0.008)
        let ringMat = SCNMaterial()
        ringMat.diffuse.contents = UIColor.white.withAlphaComponent(0.6)
        ringMat.lightingModel = .constant
        ringMat.writesToDepthBuffer = false
        ringMat.readsFromDepthBuffer = false
        ringMat.isDoubleSided = true
        ring.firstMaterial = ringMat
        areaAffectorNode = SCNNode(geometry: ring)
        areaAffectorNode.name = "area_affector"
        areaAffectorNode.renderingOrder = 90
        areaAffectorNode.isHidden = false

        // Trajectory dots
        trajectoryContainer.name = "trajectory"
        for i in 0..<trajectoryDotCount {
            let radius = CGFloat(0.015 - Float(i) * 0.001)
            let sphere = SCNSphere(radius: max(radius, 0.005))
            let mat = SCNMaterial()
            mat.diffuse.contents = UIColor.white.withAlphaComponent(CGFloat(0.9 - Float(i) * 0.06))
            mat.lightingModel = .constant
            mat.writesToDepthBuffer = false
            mat.readsFromDepthBuffer = false
            sphere.firstMaterial = mat
            let dot = SCNNode(geometry: sphere)
            dot.isHidden = true
            dot.renderingOrder = 100
            trajectoryDots.append(dot)
            trajectoryContainer.addChildNode(dot)
        }
    }

    func addToScene(_ parentNode: SCNNode) {
        parentNode.addChildNode(trajectoryContainer)
    }

    // MARK: - Placement

    func placeBall(at position: SCNVector3) {
        ballNode.removeAllActions()

        // Ball center at Y=0.07: rests exactly on floor plane at Y=0.035 (0.035 + radius 0.035)
        // Ball starts kinematic with no gravity - perfectly still until first shot
        ballNode.position = SCNVector3(position.x, 0.07, position.z)
        ballNode.physicsBody?.velocity = SCNVector3Zero
        ballNode.physicsBody?.angularVelocity = SCNVector4Zero
        ballNode.physicsBody?.type = .kinematic
        ballNode.physicsBody?.isAffectedByGravity = false
        ballNode.isHidden = false
        ballNode.opacity = 1.0
        ballNode.scale = SCNVector3(1, 1, 1)
        ballIsStatic = true
        pendingShot = nil
        shotGraceFrames = 0

        areaAffectorNode.position = SCNVector3(position.x, 0.05, position.z)
        areaAffectorNode.isHidden = false
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
        hideTrajectory()

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
        let dx = endPos.x - startPos.x
        let dz = endPos.z - startPos.z
        let distance = sqrt(dx * dx + dz * dz)
        force = min(distance * forceModifier, maxForce)

        // Shot direction = opposite of drag direction (slingshot pull-back)
        direction = SCNVector3(-dx, 0, -dz)

        updateTrajectoryDots()
    }

    private func resetAim() {
        isAiming = false
        force = 0
        direction = SCNVector3Zero
        startPos = SCNVector3Zero
        endPos = SCNVector3Zero
        hideTrajectory()
    }

    // MARK: - Trajectory Dots

    private func updateTrajectoryDots() {
        guard force > 0.01 else {
            hideTrajectory()
            return
        }

        let len = sqrt(direction.x * direction.x + direction.z * direction.z)
        guard len > 0.001 else {
            hideTrajectory()
            return
        }

        let ballPos = worldPosition
        let nx = direction.x / len
        let nz = direction.z / len
        let power = force / maxForce
        let maxLength: Float = 1.8

        for (i, dot) in trajectoryDots.enumerated() {
            let t = Float(i + 1) / Float(trajectoryDotCount)
            let dist = t * power * maxLength
            dot.position = SCNVector3(
                ballPos.x + nx * dist,
                0.06,
                ballPos.z + nz * dist
            )
            dot.isHidden = false
        }
    }

    private func hideTrajectory() {
        for dot in trajectoryDots {
            dot.isHidden = true
        }
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
            shotGraceFrames = 10

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

            if speed < 0.02 && angularSpeed < 0.06 {
                ballIsStatic = true
                body.velocity = SCNVector3Zero
                body.angularVelocity = SCNVector4Zero
                let pos = worldPosition
                ballNode.position = pos
                areaAffectorNode.isHidden = false
                areaAffectorNode.position = SCNVector3(pos.x, 0.05, pos.z)
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
