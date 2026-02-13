import SceneKit

/// Matches Unity BallControl.cs aiming system:
/// - Slingshot pull-back: drag away from ball, shot goes opposite direction
/// - Trajectory dots show shot direction and power
/// - Force = clamp(distance * modifier, 0, maxForce)
class ClubController {

    // MARK: - Configuration (Unity: MaxForce, forceModifier)

    let maxForce: Float = 0.3
    let forceModifier: Float = 0.12

    // MARK: - Aiming State

    private(set) var startPos: SCNVector3 = SCNVector3Zero  // Ball position (anchor)
    private(set) var endPos: SCNVector3 = SCNVector3Zero     // Current touch world position
    private(set) var force: Float = 0
    private(set) var direction: SCNVector3 = SCNVector3Zero  // Unnormalized shot direction
    private(set) var isAiming: Bool = false

    /// Normalized power 0..1 for UI power bar
    var normalizedPower: Float {
        maxForce > 0 ? force / maxForce : 0
    }

    // MARK: - Trajectory Dots (replaces Unity LineRenderer)

    private let trajectoryDotCount = 10
    private var trajectoryDots: [SCNNode] = []
    private let trajectoryContainer = SCNNode()

    init(color: String = "red") {
        trajectoryContainer.name = "trajectory"

        for i in 0..<trajectoryDotCount {
            let radius = CGFloat(0.015 - Float(i) * 0.001)
            let sphere = SCNSphere(radius: max(radius, 0.005))
            let mat = SCNMaterial()
            mat.diffuse.contents = UIColor.white.withAlphaComponent(CGFloat(0.9 - Float(i) * 0.06))
            mat.lightingModel = .constant
            mat.writesToDepthBuffer = false
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

    // MARK: - Aiming Methods (Unity: MouseDownMethod / MouseNormalMethod / MouseUpMethod)

    /// Touch started near ball - begin aiming
    func mouseDown(ballPosition: SCNVector3, worldPoint: SCNVector3) {
        startPos = ballPosition
        endPos = worldPoint
        isAiming = true
        updateAiming(ballPosition: ballPosition)
    }

    /// Touch moved during aim - update direction and power
    func mouseNormal(ballPosition: SCNVector3, worldPoint: SCNVector3) {
        guard isAiming else { return }
        endPos = worldPoint
        startPos = ballPosition
        updateAiming(ballPosition: ballPosition)
    }

    /// Touch ended - return impulse vector to apply, or nil if force too low
    func mouseUp() -> SCNVector3? {
        guard isAiming else { return nil }
        isAiming = false
        hideTrajectory()

        guard force > 0.02 else {
            reset()
            return nil
        }

        let len = sqrt(direction.x * direction.x + direction.z * direction.z)
        guard len > 0.001 else {
            reset()
            return nil
        }

        let nx = direction.x / len
        let nz = direction.z / len
        let impulse = SCNVector3(nx * force, 0.005, nz * force)

        reset()
        return impulse
    }

    // MARK: - Internal

    private func updateAiming(ballPosition: SCNVector3) {
        let dx = endPos.x - startPos.x
        let dz = endPos.z - startPos.z
        let distance = sqrt(dx * dx + dz * dz)
        force = min(distance * forceModifier, maxForce)

        // Shot direction = opposite of drag direction (slingshot pull-back)
        direction = SCNVector3(-dx, 0, -dz)

        updateTrajectoryDots(ballPos: ballPosition)
    }

    private func updateTrajectoryDots(ballPos: SCNVector3) {
        guard force > 0.01 else {
            hideTrajectory()
            return
        }

        let len = sqrt(direction.x * direction.x + direction.z * direction.z)
        guard len > 0.001 else {
            hideTrajectory()
            return
        }

        let nx = direction.x / len
        let nz = direction.z / len
        let power = force / maxForce
        let maxLength: Float = 1.8

        for (i, dot) in trajectoryDots.enumerated() {
            let t = Float(i + 1) / Float(trajectoryDotCount)
            let dist = t * power * maxLength
            dot.position = SCNVector3(
                ballPos.x + nx * dist,
                0.025,
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

    // MARK: - Reset

    func reset() {
        isAiming = false
        force = 0
        direction = SCNVector3Zero
        startPos = SCNVector3Zero
        endPos = SCNVector3Zero
        hideTrajectory()
    }
}
