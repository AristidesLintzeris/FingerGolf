import SceneKit

protocol PhysicsManagerDelegate: AnyObject {
    func physicsManager(_ manager: PhysicsManager, ballDidEnterHole ballNode: SCNNode)
    func physicsManager(_ manager: PhysicsManager, ballDidHitFlagPole ballNode: SCNNode)
}

class PhysicsManager: NSObject, SCNPhysicsContactDelegate {

    weak var delegate: PhysicsManagerDelegate?

    // MARK: - Ball Physics

    func setupBallPhysics(for ballNode: SCNNode) {
        let shape = SCNPhysicsShape(
            geometry: SCNSphere(radius: 0.035),
            options: nil
        )
        // Start KINEMATIC - ball sits perfectly still until the player hits it.
        let body = SCNPhysicsBody(type: .kinematic, shape: shape)

        body.mass = 0.0459              // Standard golf ball mass (kg)
        body.restitution = 0.4          // Moderate bounciness for mini-golf
        body.friction = 0.2             // Lower friction for smoother rolling
        body.rollingFriction = 0.02     // Very low rolling resistance (like smooth felt)
        body.damping = 0.005            // Almost no air resistance
        body.angularDamping = 0.05      // Very low spin damping for longer rolls

        body.categoryBitMask = PhysicsCategory.ball
        body.collisionBitMask = PhysicsCategory.course | PhysicsCategory.flag
        body.contactTestBitMask = PhysicsCategory.hole | PhysicsCategory.flag

        body.isAffectedByGravity = false  // Off until first shot
        body.allowsResting = true
        body.continuousCollisionDetectionThreshold = 0.035 // Use radius for CCD

        ballNode.physicsBody = body
    }

    // MARK: - Course Physics

    /// Creates a unified physics body for the entire course by combining all piece meshes
    func setupUnifiedCoursePhysics(for courseRootNode: SCNNode) {
        // Collect all course piece nodes (skip hole_visual and flag)
        var coursePieces: [SCNNode] = []
        for child in courseRootNode.childNodes {
            if child.name == "hole_visual" || child.name == "flag" || child.name == "hole_trigger" {
                continue
            }
            coursePieces.append(child)
        }

        guard !coursePieces.isEmpty else { return }

        // Create a single unified physics shape from all course pieces
        // This eliminates gaps and seams between individual pieces
        let shape = SCNPhysicsShape(
            node: courseRootNode,
            options: [
                .type: SCNPhysicsShape.ShapeType.concavePolyhedron,
                .collisionMargin: NSNumber(value: 0.001),  // Very tight collision margin
                .keepAsCompound: NSNumber(value: false)     // Merge into single shape
            ]
        )

        let body = SCNPhysicsBody(type: .static, shape: shape)
        body.categoryBitMask = PhysicsCategory.course
        body.collisionBitMask = PhysicsCategory.ball

        // Physics for golf ball interaction
        body.restitution = 0.4     // Match ball restitution for consistent bounce
        body.friction = 0.3        // Moderate friction for natural rolling

        // Apply unified physics body to the course root node
        courseRootNode.physicsBody = body
    }

    /// Legacy method - kept for backward compatibility but prefer setupUnifiedCoursePhysics
    func setupCoursePiecePhysics(for pieceNode: SCNNode) {
        // Use the actual mesh geometry for accurate physics (ramps, hills, walls)
        // concavePolyhedron is required for complex static geometry
        let shape = SCNPhysicsShape(
            node: pieceNode,
            options: [
                .type: SCNPhysicsShape.ShapeType.concavePolyhedron,
                .collisionMargin: NSNumber(value: 0.005)
            ]
        )

        let body = SCNPhysicsBody(type: .static, shape: shape)
        body.categoryBitMask = PhysicsCategory.course
        body.collisionBitMask = PhysicsCategory.ball

        // Physics for golf ball interaction
        body.restitution = 0.4     // Match ball restitution for consistent bounce
        body.friction = 0.3        // Moderate friction for natural rolling

        pieceNode.physicsBody = body
    }

    // MARK: - Hole Trigger

    func setupHoleTrigger(at position: SCNVector3) -> SCNNode {
        let triggerGeometry = SCNCylinder(radius: 0.08, height: 0.02)
        triggerGeometry.firstMaterial?.diffuse.contents = UIColor.clear
        let triggerNode = SCNNode(geometry: triggerGeometry)
        triggerNode.name = "hole_trigger"
        triggerNode.position = SCNVector3(position.x, 0.06, position.z)

        let body = SCNPhysicsBody(type: .static, shape: nil)
        body.categoryBitMask = PhysicsCategory.hole
        body.collisionBitMask = 0
        body.contactTestBitMask = PhysicsCategory.ball
        triggerNode.physicsBody = body

        return triggerNode
    }

    // MARK: - Flag Physics

    func setupFlagPhysics(for flagNode: SCNNode) {
        let shape = SCNPhysicsShape(
            geometry: SCNCylinder(radius: 0.06, height: 0.5),
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
