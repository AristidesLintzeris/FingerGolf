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
        // Switched to dynamic on first shot by BallController.
        let body = SCNPhysicsBody(type: .kinematic, shape: shape)

        body.mass = 0.0459
        body.restitution = 0.5
        body.friction = 0.3
        body.rollingFriction = 0.08
        body.angularDamping = 0.15
        body.damping = 0.01

        body.categoryBitMask = PhysicsCategory.ball
        body.collisionBitMask = PhysicsCategory.course | PhysicsCategory.flag
        body.contactTestBitMask = PhysicsCategory.hole | PhysicsCategory.flag

        body.isAffectedByGravity = false  // Off until first shot
        body.allowsResting = true
        body.continuousCollisionDetectionThreshold = 0.035

        ballNode.physicsBody = body
    }

    // MARK: - Course Physics

    func setupCoursePiecePhysics(for pieceNode: SCNNode) {
        let (minBound, maxBound) = pieceNode.boundingBox
        let width = CGFloat(maxBound.x - minBound.x)
        let depth = CGFloat(maxBound.z - minBound.z)
        let pieceHeight = maxBound.y - minBound.y

        // 1. Wall physics from mesh - MUST be created BEFORE adding floor plane child
        //    so the concave polyhedron only contains the original model geometry.
        //    Only for pieces with significant height (actual walls/borders).
        if pieceHeight > 0.08 {
            let shape = SCNPhysicsShape(
                node: pieceNode,
                options: [
                    .type: SCNPhysicsShape.ShapeType.concavePolyhedron,
                    .collisionMargin: NSNumber(value: 0.003)
                ]
            )
            let body = SCNPhysicsBody(type: .static, shape: shape)
            body.categoryBitMask = PhysicsCategory.course
            body.collisionBitMask = PhysicsCategory.ball
            body.restitution = 0.5
            body.friction = 0.2
            pieceNode.physicsBody = body
        }

        // 2. Invisible floor plane for smooth rolling - added AFTER wall physics
        //    so it's not included in the concave polyhedron shape.
        //    Positioned at Y=0.035 so ball (radius 0.035) center sits at Y=0.07,
        //    well above the mesh floor triangles (~Y=0.02-0.03).
        if width > 0.1 && depth > 0.1 {
            let overlap: CGFloat = 0.02
            let floorPlane = SCNPlane(width: width + overlap, height: depth + overlap)
            let floorNode = SCNNode(geometry: floorPlane)
            floorNode.name = "floor_plane"
            floorNode.position = SCNVector3(
                (minBound.x + maxBound.x) / 2,
                0.035,
                (minBound.z + maxBound.z) / 2
            )
            floorNode.eulerAngles.x = -.pi / 2
            floorNode.opacity = 0.0

            let floorShape = SCNPhysicsShape(geometry: floorPlane, options: nil)
            let floorBody = SCNPhysicsBody(type: .static, shape: floorShape)
            floorBody.categoryBitMask = PhysicsCategory.course
            floorBody.collisionBitMask = PhysicsCategory.ball
            floorBody.friction = 0.15
            floorBody.restitution = 0.05
            floorNode.physicsBody = floorBody

            pieceNode.addChildNode(floorNode)
        }
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
