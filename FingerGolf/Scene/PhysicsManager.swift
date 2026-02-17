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
            options: [.collisionMargin: NSNumber(value: 0.001)]
        )
        let body = SCNPhysicsBody(type: .dynamic, shape: shape)

        // Mass: standard golf ball
        body.mass = 0.0459

        // Bounce: moderate — realistic ricochets off walls without pinball energy
        body.restitution = 0.4

        // Surface friction: enough grip so the ball doesn't slide on moderate slopes
        // but still rolls freely on flat surfaces. Combined with course friction
        // this determines whether the ball holds position on inclines.
        body.friction = 0.2

        // Rolling friction: constant opposing torque that decelerates the ball.
        // Keep LOW so the ball coasts gently at low speeds instead of stopping abruptly.
        body.rollingFriction = 0.0015

        // Linear damping: velocity-proportional drag.
        // This is the PRIMARY deceleration force — strong when fast, gentle when slow.
        // Creates the natural "coast to a halt" feel instead of a constant-rate stop.
        body.damping = 0.0005

        // Angular damping: how quickly spin decays.
        body.angularDamping = 0.008

        // Collision categories
        body.categoryBitMask = PhysicsCategory.ball
        body.collisionBitMask = PhysicsCategory.course | PhysicsCategory.flag
        body.contactTestBitMask = PhysicsCategory.hole | PhysicsCategory.flag

        body.isAffectedByGravity = true
        body.allowsResting = false

        // Continuous collision detection prevents the ball tunneling through
        // thin walls at high speed. Threshold = 2× ball diameter.
        body.continuousCollisionDetectionThreshold = 0.07

        ballNode.physicsBody = body
    }

    // MARK: - Course Physics

    /// Builds a single compound physics shape from all course tile meshes.
    /// Using concavePolyhedron preserves the exact mesh geometry (walls, ramps, etc).
    /// Collision margin 0.005 bridges tile seams AND prevents the ball tunneling through
    /// thin geometry (e.g., skew-corner walls that taper to zero thickness at diagonal edges).
    func setupUnifiedCoursePhysics(for courseRootNode: SCNNode) {
        let excludedNames: Set<String> = ["hole_visual", "flag", "hole_trigger"]
        let coursePieces = courseRootNode.childNodes.filter {
            !excludedNames.contains($0.name ?? "")
        }
        guard !coursePieces.isEmpty else { return }

        var shapes: [SCNPhysicsShape] = []
        var transforms: [NSValue] = []

        for piece in coursePieces {
            collectShapes(
                from: piece,
                parentTransform: piece.transform,
                shapes: &shapes,
                transforms: &transforms
            )
        }

        guard !shapes.isEmpty else { return }

        let compound = SCNPhysicsShape(shapes: shapes, transforms: transforms)
        let body = SCNPhysicsBody(type: .static, shape: compound)
        body.categoryBitMask = PhysicsCategory.course
        body.collisionBitMask = PhysicsCategory.ball

        // Course surface properties — moderate friction for natural rolling
        body.friction = 0.3
        body.restitution = 0.4

        courseRootNode.physicsBody = body
    }

    /// Recursively collects geometry from a node tree, building concavePolyhedron
    /// shapes positioned via their accumulated world transforms.
    private func collectShapes(
        from node: SCNNode,
        parentTransform: SCNMatrix4,
        shapes: inout [SCNPhysicsShape],
        transforms: inout [NSValue]
    ) {
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
            let childTransform = SCNMatrix4Mult(child.transform, parentTransform)
            collectShapes(
                from: child,
                parentTransform: childTransform,
                shapes: &shapes,
                transforms: &transforms
            )
        }
    }

    // MARK: - Hole Trigger

    func setupHoleTrigger(at position: SCNVector3) -> SCNNode {
        let geo = SCNCylinder(radius: 0.08, height: 0.02)
        geo.firstMaterial?.diffuse.contents = UIColor.clear
        let node = SCNNode(geometry: geo)
        node.name = "hole_trigger"
        node.position = SCNVector3(position.x, 0.15, position.z)

        let body = SCNPhysicsBody(type: .static, shape: nil)
        body.categoryBitMask = PhysicsCategory.hole
        body.collisionBitMask = 0
        body.contactTestBitMask = PhysicsCategory.ball
        node.physicsBody = body

        return node
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
