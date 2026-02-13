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
        let body = SCNPhysicsBody(type: .dynamic, shape: shape)

        body.mass = 0.0459
        body.restitution = 0.35
        body.friction = 0.5
        body.rollingFriction = 0.15
        body.angularDamping = 0.8
        body.damping = 0.3

        body.categoryBitMask = PhysicsCategory.ball
        body.collisionBitMask = PhysicsCategory.wall | PhysicsCategory.surface | PhysicsCategory.flag
        body.contactTestBitMask = PhysicsCategory.hole | PhysicsCategory.flag

        body.isAffectedByGravity = true
        body.allowsResting = true
        body.continuousCollisionDetectionThreshold = 0.035

        ballNode.physicsBody = body
    }

    // MARK: - Course Physics

    func setupCoursePiecePhysics(for pieceNode: SCNNode) {
        let (minBound, maxBound) = pieceNode.boundingBox
        let width = CGFloat(maxBound.x - minBound.x)
        let depth = CGFloat(maxBound.z - minBound.z)

        // Create invisible floor plane at Y=0 for smooth rolling surface.
        // Positioned slightly above the mesh surface so the ball rolls on the
        // smooth plane rather than the mesh triangles.
        if width > 0.1 && depth > 0.1 {
            let floorPlane = SCNPlane(width: width, height: depth)
            let floorNode = SCNNode(geometry: floorPlane)
            floorNode.name = "floor_plane"
            floorNode.position = SCNVector3(
                (minBound.x + maxBound.x) / 2,
                0.001,
                (minBound.z + maxBound.z) / 2
            )
            floorNode.eulerAngles.x = -.pi / 2
            floorNode.opacity = 0.0

            let floorShape = SCNPhysicsShape(geometry: floorPlane, options: nil)
            let floorBody = SCNPhysicsBody(type: .static, shape: floorShape)
            floorBody.categoryBitMask = PhysicsCategory.surface
            floorBody.collisionBitMask = PhysicsCategory.ball
            floorBody.friction = 0.5
            floorBody.restitution = 0.0
            floorNode.physicsBody = floorBody

            pieceNode.addChildNode(floorNode)
        }

        // Add wall physics to all child geometry (edges, walls, ramps)
        pieceNode.enumerateChildNodes { child, _ in
            guard let geometry = child.geometry else { return }
            guard child.name != "floor_plane" else { return }

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
            body.restitution = 0.5
            body.friction = 0.3
            child.physicsBody = body
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
