import SceneKit
import QuartzCore

class TrajectoryPreview {

    // MARK: - Configuration

    private let pointCount: Int = 25
    private let dotRadius: CGFloat = 0.012
    private let timeStep: Float = 0.04

    // Physics constants matching PhysicsManager / BallController
    private let ballMass: Float = 0.045
    private let gravity: simd_float3 = simd_float3(0, -9.8, 0)
    private let linearDamping: Float = 0.1
    private let floorY: Float = 0.065

    // MARK: - Nodes

    private let containerNode: SCNNode
    private var dotNodes: [SCNNode] = []
    private let dimMaterial: SCNMaterial
    private let brightMaterial: SCNMaterial

    // MARK: - State

    private(set) var isVisible = false

    init() {
        containerNode = SCNNode()
        containerNode.name = "trajectory_preview"
        containerNode.isHidden = true

        // Dim material: aiming state
        dimMaterial = SCNMaterial()
        dimMaterial.diffuse.contents = UIColor.white.withAlphaComponent(0.3)
        dimMaterial.lightingModel = .constant
        dimMaterial.blendMode = .add
        dimMaterial.writesToDepthBuffer = false
        dimMaterial.isDoubleSided = true

        // Bright material: flick in progress
        brightMaterial = SCNMaterial()
        brightMaterial.diffuse.contents = UIColor.white.withAlphaComponent(0.7)
        brightMaterial.lightingModel = .constant
        brightMaterial.blendMode = .add
        brightMaterial.writesToDepthBuffer = false
        brightMaterial.isDoubleSided = true

        // Pre-create dot nodes with shared geometry
        let dotGeometry = SCNSphere(radius: dotRadius)
        dotGeometry.segmentCount = 6
        dotGeometry.firstMaterial = dimMaterial

        for i in 0..<pointCount {
            let dot = SCNNode(geometry: dotGeometry.copy() as? SCNGeometry)
            dot.name = "trajectory_dot_\(i)"
            dot.geometry?.firstMaterial = dimMaterial
            containerNode.addChildNode(dot)
            dotNodes.append(dot)
        }
    }

    // MARK: - Scene Integration

    func addToScene(_ rootNode: SCNNode) {
        if containerNode.parent == nil {
            rootNode.addChildNode(containerNode)
        }
    }

    func removeFromScene() {
        containerNode.removeFromParentNode()
    }

    // MARK: - Update

    func update(ballPosition: SCNVector3,
                aimDirection: SCNVector3,
                power: Float,
                maxSwingPower: Float,
                bright: Bool) {

        let clampedPower = min(max(power, 0.05), 1.0)
        let forceMagnitude = clampedPower * maxSwingPower

        // Initial velocity = Force / mass (impulse)
        let forceVector = simd_float3(
            aimDirection.x * forceMagnitude,
            0.02,
            aimDirection.z * forceMagnitude
        )
        var velocity = forceVector / ballMass
        var position = simd_float3(ballPosition.x, ballPosition.y, ballPosition.z)

        let material = bright ? brightMaterial : dimMaterial

        for i in 0..<pointCount {
            // Apply gravity
            velocity += gravity * timeStep

            // Apply linear damping
            velocity *= (1.0 - linearDamping * timeStep)

            // Update position
            position += velocity * timeStep

            // Floor clamp
            if position.y < floorY {
                position.y = floorY
                velocity.y = max(velocity.y, 0)
            }

            dotNodes[i].position = SCNVector3(position.x, position.y, position.z)
            dotNodes[i].geometry?.firstMaterial = material

            // Fade dots toward the end
            let fadeProgress = Float(i) / Float(pointCount)
            let scale = 1.0 - fadeProgress * 0.6
            dotNodes[i].scale = SCNVector3(scale, scale, scale)
        }

        show()
    }

    // MARK: - Visibility

    func show() {
        guard !isVisible else { return }
        containerNode.isHidden = false
        isVisible = true
    }

    func hide() {
        containerNode.isHidden = true
        isVisible = false
    }
}
