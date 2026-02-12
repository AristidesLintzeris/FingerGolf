import SceneKit

protocol PhysicsManagerDelegate: AnyObject {
    func physicsManager(_ manager: PhysicsManager, ballDidEnterHole ballNode: SCNNode)
    func physicsManager(_ manager: PhysicsManager, ballDidHitFlagPole ballNode: SCNNode)
    func physicsManager(_ manager: PhysicsManager, ballDidFallOffCourse ballNode: SCNNode)
}

class PhysicsManager: NSObject, SCNPhysicsContactDelegate {

    weak var delegate: PhysicsManagerDelegate?
    private let settings: GameSettings

    init(settings: GameSettings) {
        self.settings = settings
        super.init()
    }

    // MARK: - Ball Physics

    func setupBallPhysics(for ballNode: SCNNode) {
        // Basic minigolf ball physics - simple sphere with Unity Rigidbody-like parameters
        // Ball can ONLY touch green surfaces, bounces off wood edges
        let shape = SCNPhysicsShape(
            geometry: SCNSphere(radius: 0.035),
            options: nil
        )
        let body = SCNPhysicsBody(type: .dynamic, shape: shape)

        // Unity Rigidbody-style settings for golf ball
        body.mass = 0.0459  // Standard golf ball mass in kg
        body.restitution = 0.35  // Slight bounce off walls (wood edges)
        body.friction = 0.5  // Good grip on green surface
        body.rollingFriction = 0.1  // Realistic rolling resistance
        body.angularDamping = 0.5  // Slower spin decay
        body.damping = 0.3  // Linear velocity damping (air resistance)

        // Physics categories - ball ONLY collides with green surface and wood walls
        body.categoryBitMask = PhysicsCategory.ball
        body.collisionBitMask = PhysicsCategory.wall | PhysicsCategory.surface | PhysicsCategory.flag
        body.contactTestBitMask = PhysicsCategory.hole | PhysicsCategory.flag

        body.isAffectedByGravity = true
        body.allowsResting = true
        body.continuousCollisionDetectionThreshold = 0.035  // Prevent tunneling through thin geometry

        ballNode.physicsBody = body
    }

    // MARK: - Course Physics

    func setupCoursePiecePhysics(for pieceNode: SCNNode) {
        // Each piece is 1x1 unit. The green area is the play surface, wood edges are walls.
        // Strategy: Add an invisible floor plane at Y=0 for the green area,
        // and use concave mesh collision for the wood edges to act as walls.

        pieceNode.enumerateChildNodes { child, _ in
            guard let geometry = child.geometry else { return }

            // Check if this is a "green" material by looking for green color
            let isGreenSurface = child.geometry?.materials.contains { material in
                if let color = material.diffuse.contents as? UIColor {
                    var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0
                    color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: nil)
                    // Green hue is around 0.25-0.45, high saturation
                    return hue > 0.2 && hue < 0.5 && saturation > 0.3
                }
                return false
            } ?? false

            if isGreenSurface {
                // Add invisible floor plane at Y=0 for green area
                let floorPlane = SCNPlane(width: 1.0, height: 1.0)
                let floorNode = SCNNode(geometry: floorPlane)
                floorNode.position = SCNVector3(0, 0, 0)
                floorNode.eulerAngles.x = -.pi / 2
                floorNode.opacity = 0.0  // invisible

                let floorShape = SCNPhysicsShape(geometry: floorPlane, options: nil)
                let floorBody = SCNPhysicsBody(type: .static, shape: floorShape)
                floorBody.categoryBitMask = PhysicsCategory.surface
                floorBody.collisionBitMask = PhysicsCategory.ball
                floorBody.friction = 0.4
                floorBody.restitution = 0.0
                floorNode.physicsBody = floorBody

                pieceNode.addChildNode(floorNode)
            } else {
                // Use concave mesh for wood edges to act as walls
                let shape = SCNPhysicsShape(
                    geometry: geometry,
                    options: [
                        .type: SCNPhysicsShape.ShapeType.concavePolyhedron,
                        .scale: child.scale
                    ]
                )
                let body = SCNPhysicsBody(type: .static, shape: shape)
                body.categoryBitMask = PhysicsCategory.wall
                body.collisionBitMask = PhysicsCategory.ball
                body.restitution = 0.6
                body.friction = 0.4
                child.physicsBody = body
            }
        }
    }

    // MARK: - Hole Trigger

    func setupHoleTrigger(at position: SCNVector3) -> SCNNode {
        let triggerGeometry = SCNCylinder(radius: 0.08, height: 0.02)
        triggerGeometry.firstMaterial?.diffuse.contents = UIColor.clear
        let triggerNode = SCNNode(geometry: triggerGeometry)
        triggerNode.name = "hole_trigger"
        triggerNode.position = SCNVector3(position.x, 0.03, position.z)

        let body = SCNPhysicsBody(type: .static, shape: nil)
        body.categoryBitMask = PhysicsCategory.hole
        body.collisionBitMask = 0  // sensor only, no physical collision
        body.contactTestBitMask = PhysicsCategory.ball
        triggerNode.physicsBody = body

        return triggerNode
    }

    // MARK: - Flag Physics

    func setupFlagPhysics(for flagNode: SCNNode) {
        // Cylindrical trigger around the flag pole
        let shape = SCNPhysicsShape(
            geometry: SCNCylinder(radius: 0.04, height: 0.5),
            options: nil
        )
        let body = SCNPhysicsBody(type: .static, shape: shape)
        body.categoryBitMask = PhysicsCategory.flag
        body.collisionBitMask = PhysicsCategory.ball
        body.contactTestBitMask = PhysicsCategory.ball
        body.restitution = 0.3
        flagNode.physicsBody = body
    }

    // MARK: - SCNPhysicsContactDelegate

    nonisolated func physicsWorld(_ world: SCNPhysicsWorld, didBegin contact: SCNPhysicsContact) {
        let maskA = contact.nodeA.physicsBody?.categoryBitMask ?? 0
        let maskB = contact.nodeB.physicsBody?.categoryBitMask ?? 0

        let isBallA = (maskA & PhysicsCategory.ball) != 0
        let isBallB = (maskB & PhysicsCategory.ball) != 0
        let isHoleA = (maskA & PhysicsCategory.hole) != 0
        let isHoleB = (maskB & PhysicsCategory.hole) != 0
        let isFlagA = (maskA & PhysicsCategory.flag) != 0
        let isFlagB = (maskB & PhysicsCategory.flag) != 0

        if (isBallA && isHoleB) || (isBallB && isHoleA) {
            let ballNode = isBallA ? contact.nodeA : contact.nodeB
            Task { @MainActor in
                self.delegate?.physicsManager(self, ballDidEnterHole: ballNode)
            }
        }

        if (isBallA && isFlagB) || (isBallB && isFlagA) {
            let ballNode = isBallA ? contact.nodeA : contact.nodeB
            Task { @MainActor in
                self.delegate?.physicsManager(self, ballDidHitFlagPole: ballNode)
            }
        }
    }
}
