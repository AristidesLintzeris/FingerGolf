import SceneKit
import QuartzCore

class TrajectoryPreview {

    // MARK: - Configuration

    private let pointCount: Int = 25
    private let dotRadius: CGFloat = 0.012
    private let maxLineLength: Float = 3.0

    // MARK: - Nodes

    private let containerNode: SCNNode
    private var dotNodes: [SCNNode] = []
    private let material: SCNMaterial

    // MARK: - State

    private(set) var isVisible = false

    init() {
        containerNode = SCNNode()
        containerNode.name = "trajectory_preview"
        containerNode.isHidden = true

        // Dashed line material
        material = SCNMaterial()
        material.diffuse.contents = UIColor.white.withAlphaComponent(0.6)
        material.lightingModel = .constant
        material.blendMode = .add
        material.writesToDepthBuffer = false
        material.isDoubleSided = true

        // Pre-create dot nodes
        let dotGeometry = SCNSphere(radius: dotRadius)
        dotGeometry.segmentCount = 6
        dotGeometry.firstMaterial = material

        for i in 0..<pointCount {
            let dot = SCNNode(geometry: dotGeometry.copy() as? SCNGeometry)
            dot.name = "trajectory_dot_\(i)"
            dot.geometry?.firstMaterial = material
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

    /// Update trajectory as a dashed line from ball in the aim direction.
    /// Length is proportional to power.
    func update(ballPosition: SCNVector3,
                direction: SCNVector3,
                power: Float) {

        let clampedPower = min(max(power, 0.0), 1.0)
        let lineLength = clampedPower * maxLineLength
        let spacing = lineLength / Float(pointCount)

        for i in 0..<pointCount {
            let t = Float(i + 1) * spacing
            let x = ballPosition.x + direction.x * t
            let z = ballPosition.z + direction.z * t

            dotNodes[i].position = SCNVector3(x, 0.07, z)

            // Fade dots toward the end
            let fadeProgress = Float(i) / Float(pointCount)
            let scale = 1.0 - fadeProgress * 0.6
            dotNodes[i].scale = SCNVector3(scale, scale, scale)
            dotNodes[i].isHidden = (t > lineLength + 0.01)
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
