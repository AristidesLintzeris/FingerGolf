import SceneKit

class ClubController {

    let clubNode: SCNNode
    private(set) var placementPosition: SCNVector3?
    private(set) var aimDirection: SCNVector3?
    private(set) var aimAngle: Float = 0

    // Visual aim indicator
    private let aimLineNode: SCNNode
    private let aimDotNode: SCNNode

    init(color: String = "red") {
        let modelName = "club-\(color)"
        if let loaded = AssetCatalog.shared.loadPiece(named: modelName) {
            clubNode = loaded
        } else {
            // Fallback: simple cylinder
            let cylinder = SCNCylinder(radius: 0.01, height: 0.3)
            cylinder.firstMaterial?.diffuse.contents = UIColor.gray
            clubNode = SCNNode(geometry: cylinder)
        }
        clubNode.name = "golf_club"
        clubNode.isHidden = true

        // Aim line indicator
        let lineGeometry = SCNCylinder(radius: 0.005, height: 1.0)
        lineGeometry.firstMaterial?.diffuse.contents = UIColor.white.withAlphaComponent(0.5)
        aimLineNode = SCNNode(geometry: lineGeometry)
        aimLineNode.name = "aim_line"
        aimLineNode.eulerAngles.x = .pi / 2  // lay flat
        aimLineNode.position = SCNVector3(0, 0.07, 0.5) // extend forward
        aimLineNode.isHidden = true

        // Aim dot at the end of the line
        let dotGeometry = SCNSphere(radius: 0.02)
        dotGeometry.firstMaterial?.diffuse.contents = UIColor.white.withAlphaComponent(0.6)
        aimDotNode = SCNNode(geometry: dotGeometry)
        aimDotNode.name = "aim_dot"
        aimDotNode.isHidden = true
    }

    func addToScene(_ parentNode: SCNNode) {
        parentNode.addChildNode(clubNode)
        parentNode.addChildNode(aimLineNode)
        parentNode.addChildNode(aimDotNode)
    }

    // MARK: - Placement

    func positionClub(at worldPosition: SCNVector3) {
        placementPosition = worldPosition
        clubNode.position = SCNVector3(worldPosition.x, 0, worldPosition.z)
        clubNode.isHidden = false
        aimLineNode.isHidden = false
        aimDotNode.isHidden = false
    }

    func updateAimDirection(toward targetPosition: SCNVector3) {
        guard let start = placementPosition else { return }

        let dx = targetPosition.x - start.x
        let dz = targetPosition.z - start.z
        let distance = sqrt(dx * dx + dz * dz)

        guard distance > 0.01 else { return }

        // Normalize direction
        aimDirection = SCNVector3(dx / distance, 0, dz / distance)
        aimAngle = atan2(dx, dz)

        // Rotate club to face aim direction
        clubNode.eulerAngles.y = aimAngle

        // Update aim line
        let lineLength = min(distance, 2.0)
        let midX = start.x + dx / distance * lineLength / 2
        let midZ = start.z + dz / distance * lineLength / 2
        aimLineNode.position = SCNVector3(midX, 0.07, midZ)
        aimLineNode.eulerAngles.y = aimAngle

        if let lineGeom = aimLineNode.geometry as? SCNCylinder {
            lineGeom.height = CGFloat(lineLength)
        }

        // Update aim dot
        aimDotNode.position = SCNVector3(
            start.x + dx / distance * lineLength,
            0.07,
            start.z + dz / distance * lineLength
        )
    }

    // MARK: - Swing Animation

    func playSwingAnimation(power: CGFloat, completion: @escaping () -> Void) {
        let swingAngle = CGFloat.pi / 4 * power

        // Backswing
        let backswing = SCNAction.rotateBy(
            x: CGFloat(-swingAngle * 0.8), y: 0, z: 0,
            duration: 0.1
        )
        // Forward swing (fast)
        let forwardSwing = SCNAction.rotateBy(
            x: CGFloat(swingAngle * 1.6), y: 0, z: 0,
            duration: 0.08
        )
        // Follow through
        let followThrough = SCNAction.rotateBy(
            x: CGFloat(-swingAngle * 0.8), y: 0, z: 0,
            duration: 0.15
        )

        let sequence = SCNAction.sequence([backswing, forwardSwing, followThrough])
        clubNode.runAction(sequence) {
            completion()
        }
    }

    // MARK: - Hide/Reset

    func hideClub() {
        clubNode.isHidden = true
        aimLineNode.isHidden = true
        aimDotNode.isHidden = true
        placementPosition = nil
        aimDirection = nil
    }

    func reset() {
        hideClub()
        clubNode.eulerAngles = SCNVector3Zero
    }
}
