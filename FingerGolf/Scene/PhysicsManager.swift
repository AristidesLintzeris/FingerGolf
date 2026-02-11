import SceneKit

protocol PhysicsManagerDelegate: AnyObject {
    func physicsManager(_ manager: PhysicsManager, ballDidEnterHole ballNode: SCNNode)
    func physicsManager(_ manager: PhysicsManager, ballDidHitBarrier contact: SCNPhysicsContact)
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
        let shape = SCNPhysicsShape(
            geometry: SCNSphere(radius: 0.035),
            options: nil
        )
        let body = SCNPhysicsBody(type: .dynamic, shape: shape)
        body.mass = 0.045
        body.restitution = 0.5
        body.friction = 0.3
        body.rollingFriction = 0.05
        body.angularDamping = 0.3
        body.damping = 0.1
        body.categoryBitMask = PhysicsCategory.ball
        body.collisionBitMask = PhysicsCategory.wall | PhysicsCategory.obstacle |
                                PhysicsCategory.barrier | PhysicsCategory.surface
        body.contactTestBitMask = PhysicsCategory.hole | PhysicsCategory.barrier
        body.isAffectedByGravity = true
        body.allowsResting = true
        ballNode.physicsBody = body
    }

    // MARK: - Course Physics

    func setupCoursePiecePhysics(for pieceNode: SCNNode) {
        pieceNode.enumerateChildNodes { child, _ in
            guard let geometry = child.geometry else { return }

            let shape = SCNPhysicsShape(
                geometry: geometry,
                options: [
                    .type: SCNPhysicsShape.ShapeType.concavePolyhedron,
                    .scale: child.scale
                ]
            )
            let body = SCNPhysicsBody(type: .static, shape: shape)
            body.categoryBitMask = PhysicsCategory.wall | PhysicsCategory.surface
            body.collisionBitMask = PhysicsCategory.ball
            body.restitution = 0.6
            body.friction = 0.4
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
        body.collisionBitMask = 0  // sensor only, no physical collision
        body.contactTestBitMask = PhysicsCategory.ball
        triggerNode.physicsBody = body

        return triggerNode
    }

    // MARK: - Barriers

    func setupBarriers(around courseNode: SCNNode) -> [SCNNode] {
        guard settings.barrierMode == .barrier else { return [] }

        let (minBound, maxBound) = courseNode.boundingBox
        let padding: Float = 0.1
        let wallHeight: Float = 1.0
        let wallThickness: Float = 0.05

        let width = maxBound.x - minBound.x + padding * 2
        let depth = maxBound.z - minBound.z + padding * 2
        let centerX = (minBound.x + maxBound.x) / 2
        let centerZ = (minBound.z + maxBound.z) / 2

        var barriers: [SCNNode] = []

        // Create 4 walls around the course
        let wallConfigs: [(SCNVector3, SCNVector3)] = [
            // North wall
            (SCNVector3(centerX, wallHeight / 2, maxBound.z + padding),
             SCNVector3(width, wallHeight, wallThickness)),
            // South wall
            (SCNVector3(centerX, wallHeight / 2, minBound.z - padding),
             SCNVector3(width, wallHeight, wallThickness)),
            // East wall
            (SCNVector3(maxBound.x + padding, wallHeight / 2, centerZ),
             SCNVector3(wallThickness, wallHeight, depth)),
            // West wall
            (SCNVector3(minBound.x - padding, wallHeight / 2, centerZ),
             SCNVector3(wallThickness, wallHeight, depth)),
        ]

        for (position, size) in wallConfigs {
            let barrierNode = SCNNode()
            barrierNode.name = "barrier"
            barrierNode.position = position
            // Invisible - no geometry rendered
            let shape = SCNPhysicsShape(
                geometry: SCNBox(width: CGFloat(size.x), height: CGFloat(size.y),
                                 length: CGFloat(size.z), chamferRadius: 0),
                options: nil
            )
            let body = SCNPhysicsBody(type: .static, shape: shape)
            body.categoryBitMask = PhysicsCategory.barrier
            body.collisionBitMask = PhysicsCategory.ball
            body.contactTestBitMask = PhysicsCategory.ball
            body.restitution = 0.8
            barrierNode.physicsBody = body
            barriers.append(barrierNode)
        }

        return barriers
    }

    // MARK: - SCNPhysicsContactDelegate

    nonisolated func physicsWorld(_ world: SCNPhysicsWorld, didBegin contact: SCNPhysicsContact) {
        let maskA = contact.nodeA.physicsBody?.categoryBitMask ?? 0
        let maskB = contact.nodeB.physicsBody?.categoryBitMask ?? 0

        let isBallA = (maskA & PhysicsCategory.ball) != 0
        let isBallB = (maskB & PhysicsCategory.ball) != 0
        let isHoleA = (maskA & PhysicsCategory.hole) != 0
        let isHoleB = (maskB & PhysicsCategory.hole) != 0
        let isBarrierA = (maskA & PhysicsCategory.barrier) != 0
        let isBarrierB = (maskB & PhysicsCategory.barrier) != 0

        if (isBallA && isHoleB) || (isBallB && isHoleA) {
            let ballNode = isBallA ? contact.nodeA : contact.nodeB
            Task { @MainActor in
                self.delegate?.physicsManager(self, ballDidEnterHole: ballNode)
            }
        }

        if (isBallA && isBarrierB) || (isBallB && isBarrierA) {
            Task { @MainActor in
                self.delegate?.physicsManager(self, ballDidHitBarrier: contact)
            }
        }
    }
}
