import SceneKit

protocol PhysicsManagerDelegate: AnyObject {
    func physicsManager(_ manager: PhysicsManager, ballDidEnterHole ballNode: SCNNode)
    func physicsManager(_ manager: PhysicsManager, ballDidHitFlagPole ballNode: SCNNode)
}

class PhysicsManager: NSObject, SCNPhysicsContactDelegate {

    weak var delegate: PhysicsManagerDelegate?

    // MARK: - Ball Physics

    func setupBallPhysics(for ballNode: SCNNode) {
        // Collision shape: sphere matching ball geometry with small margin for stability
        let shape = SCNPhysicsShape(
            geometry: SCNSphere(radius: 0.035),
            options: [.collisionMargin: NSNumber(value: 0.002)]
        )
        let body = SCNPhysicsBody(type: .dynamic, shape: shape)

        // --- Mass & Bounce ---
        body.mass = 0.0459              // Standard golf ball mass in kg
        body.restitution = 0.15         // Low bounce: ball stays grounded and rolls instead of bouncing

        // --- Friction & Damping ---
        // These control how quickly the ball decelerates while rolling.
        // Higher values = ball slows down faster = more natural-looking deceleration.
        body.friction = 0.02            // Surface contact friction (grip on the green)
        body.rollingFriction = 0.04     // Rolling resistance: primary deceleration force (smooth curve)
        body.damping = 0.01            // Linear velocity damping: simulates air resistance
        body.angularDamping = 0.09       // Angular velocity damping: how quickly spin decays

        // --- Collision Categories ---
        body.categoryBitMask = PhysicsCategory.ball
        body.collisionBitMask = PhysicsCategory.course | PhysicsCategory.flag
        body.contactTestBitMask = PhysicsCategory.hole | PhysicsCategory.flag

        // --- Physics Behavior ---
        body.isAffectedByGravity = true
        body.allowsResting = true       // Let SceneKit auto-rest the ball when nearly stopped
        // Continuous collision detection: prevents ball tunneling through thin surfaces at high speed
        body.continuousCollisionDetectionThreshold = 0.07 // 2x ball diameter

        ballNode.physicsBody = body
    }

    // MARK: - Course Physics (compound per-piece + safety floor)

    func setupUnifiedCoursePhysics(for courseRootNode: SCNNode) {
        // Separate course pieces from non-physics nodes
        let excludedNames: Set<String> = ["hole_visual", "flag", "hole_trigger", "safety_floor"]
        let coursePieces = courseRootNode.childNodes.filter { !excludedNames.contains($0.name ?? "") }

        guard !coursePieces.isEmpty else { return }

        // Build per-piece concavePolyhedron shapes with generous collision margin.
        // The 0.005 margin inflates each piece's collision surface outward,
        // bridging the 0.0001-unit gaps at tile seams (Kenney tiles use ±0.49995 not ±0.5).
        var shapes: [SCNPhysicsShape] = []
        var transforms: [NSValue] = []

        for piece in coursePieces {
            collectShapes(from: piece, parentTransform: piece.transform, shapes: &shapes, transforms: &transforms)
        }

        guard !shapes.isEmpty else { return }

        let compoundShape = SCNPhysicsShape(shapes: shapes, transforms: transforms)

        let body = SCNPhysicsBody(type: .static, shape: compoundShape)
        body.categoryBitMask = PhysicsCategory.course
        body.collisionBitMask = PhysicsCategory.ball
        body.restitution = 0.15
        body.friction = 0.3

        courseRootNode.physicsBody = body

        // Add safety floor to catch any ball that clips through seams
        addSafetyFloor(to: courseRootNode)
    }

    /// Recursively collect geometry from a node tree into physics shapes
    private func collectShapes(from node: SCNNode, parentTransform: SCNMatrix4, shapes: inout [SCNPhysicsShape], transforms: inout [NSValue]) {
        if let geometry = node.geometry {
            let shape = SCNPhysicsShape(
                geometry: geometry,
                options: [
                    .type: SCNPhysicsShape.ShapeType.concavePolyhedron,
                    .collisionMargin: NSNumber(value: 0.005)
                ]
            )
            shapes.append(shape)
            transforms.append(NSValue(scnMatrix4: parentTransform))
        }

        for child in node.childNodes {
            let childWorldTransform = SCNMatrix4Mult(child.transform, parentTransform)
            collectShapes(from: child, parentTransform: childWorldTransform, shapes: &shapes, transforms: &transforms)
        }
    }

    /// Invisible floor plane spanning the entire course, just below the play surface (Y≈0.063).
    /// Catches any ball that clips through triangle mesh seams.
    private func addSafetyFloor(to courseRootNode: SCNNode) {
        let (minBound, maxBound) = courseRootNode.boundingBox
        let width = maxBound.x - minBound.x + 2.0
        let length = maxBound.z - minBound.z + 2.0
        let centerX = (maxBound.x + minBound.x) / 2
        let centerZ = (maxBound.z + minBound.z) / 2

        let floorGeo = SCNBox(width: CGFloat(width), height: 0.02, length: CGFloat(length), chamferRadius: 0)
        floorGeo.firstMaterial?.diffuse.contents = UIColor.clear
        floorGeo.firstMaterial?.transparency = 0

        let floorNode = SCNNode(geometry: floorGeo)
        floorNode.name = "safety_floor"
        // Top surface at Y=0.03, just below mesh play surface (Y=0.063)
        floorNode.position = SCNVector3(centerX, 0.02, centerZ)

        let floorShape = SCNPhysicsShape(
            geometry: floorGeo,
            options: [.type: SCNPhysicsShape.ShapeType.boundingBox]
        )
        let floorBody = SCNPhysicsBody(type: .static, shape: floorShape)
        floorBody.categoryBitMask = PhysicsCategory.course
        floorBody.collisionBitMask = PhysicsCategory.ball
        floorBody.friction = 0.3
        floorBody.restitution = 0.2
        floorNode.physicsBody = floorBody

        courseRootNode.addChildNode(floorNode)
    }

    // MARK: - Hole Trigger

    func setupHoleTrigger(at position: SCNVector3) -> SCNNode {
        let geo = SCNCylinder(radius: 0.08, height: 0.02)
        geo.firstMaterial?.diffuse.contents = UIColor.clear
        let triggerNode = SCNNode(geometry: geo)
        triggerNode.name = "hole_trigger"
        // Position at play surface level (Y=0.063)
        triggerNode.position = SCNVector3(position.x, 0.07, position.z)

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
