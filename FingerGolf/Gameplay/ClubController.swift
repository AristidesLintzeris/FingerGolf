import SceneKit

class ClubController {

    let clubNode: SCNNode
    private(set) var placementPosition: SCNVector3?
    private(set) var aimDirection: SCNVector3?
    private(set) var aimAngle: Float = 0
    private var clubHeight: Float = 0.15

    // Ring placement
    let placementRadius: Float = 0.6
    private let previewDotNode: SCNNode
    private let ringNode: SCNNode

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

        // Compute club height and set pivot at handle (top) for swing rotation
        let (minBound, maxBound) = clubNode.boundingBox
        let handleY = maxBound.y
        clubHeight = handleY - minBound.y
        clubNode.pivot = SCNMatrix4MakeTranslation(0, handleY, 0)

        // Preview dot: small white sphere shown on ring during placement
        let dotGeometry = SCNSphere(radius: 0.015)
        let dotMat = SCNMaterial()
        dotMat.diffuse.contents = UIColor.white.withAlphaComponent(0.8)
        dotMat.lightingModel = .constant
        dotGeometry.firstMaterial = dotMat
        previewDotNode = SCNNode(geometry: dotGeometry)
        previewDotNode.name = "placement_preview_dot"
        previewDotNode.isHidden = true

        // Ring indicator: faint torus showing the placement circle
        let ringGeometry = SCNTorus(ringRadius: CGFloat(placementRadius), pipeRadius: 0.003)
        let ringMat = SCNMaterial()
        ringMat.diffuse.contents = UIColor.white.withAlphaComponent(0.2)
        ringMat.lightingModel = .constant
        ringMat.writesToDepthBuffer = false
        ringGeometry.firstMaterial = ringMat
        ringNode = SCNNode(geometry: ringGeometry)
        ringNode.name = "placement_ring"
        ringNode.isHidden = true
    }

    func addToScene(_ parentNode: SCNNode) {
        parentNode.addChildNode(clubNode)
        parentNode.addChildNode(previewDotNode)
        parentNode.addChildNode(ringNode)
    }

    // MARK: - Ring-Based Placement

    /// Show club on the ring around ball at the given angle. Called during drag.
    func showOnRing(ballPosition: SCNVector3, angle: Float) {
        let clubX = ballPosition.x + placementRadius * sin(angle)
        let clubZ = ballPosition.z + placementRadius * cos(angle)
        let clubPos = SCNVector3(clubX, 0, clubZ)

        placementPosition = clubPos

        // Club faces inward toward ball
        let faceAngle = angle + .pi
        aimAngle = faceAngle
        clubNode.eulerAngles.y = angle  // Club body points outward, swing goes inward

        // Shot direction: from club toward ball (and beyond)
        let dx = ballPosition.x - clubX
        let dz = ballPosition.z - clubZ
        let dist = sqrt(dx * dx + dz * dz)
        if dist > 0.001 {
            aimDirection = SCNVector3(dx / dist, 0, dz / dist)
        }

        // Position club MUCH HIGHER so swing visibly hits the ball
        // Club should be well above ground, ready to swing down
        let clubRaisedHeight: Float = 0.5  // Raise club high above ground
        clubNode.position = SCNVector3(clubX, clubRaisedHeight, clubZ)
        clubNode.isHidden = false

        // Show preview dot at club position
        previewDotNode.position = SCNVector3(clubX, 0.07, clubZ)
        previewDotNode.isHidden = false

        // Show ring around ball
        ringNode.position = SCNVector3(ballPosition.x, 0.005, ballPosition.z)
        ringNode.isHidden = false
    }

    /// Lock the club in place after releasing the placement touch.
    func placeOnRing() {
        // Hide preview helpers, keep club visible
        previewDotNode.isHidden = true
        ringNode.isHidden = true
    }

    // MARK: - Swing Animation

    func playSwingAnimation(power: CGFloat, completion: @escaping () -> Void) {
        // Natural golf swing: backswing -> downswing (hit) -> follow through
        // More power = bigger backswing

        let maxBackswingAngle = CGFloat.pi / 3  // 60° max backswing
        let backswingAngle = maxBackswingAngle * power

        // Backswing: lift club back and up
        let backswing = SCNAction.rotateBy(
            x: -backswingAngle, y: 0, z: 0,
            duration: 0.15 + Double(power) * 0.1  // Longer backswing for more power
        )

        // Downswing: fast swing down to hit ball (should visually connect with ball)
        let downswing = SCNAction.rotateBy(
            x: backswingAngle + CGFloat.pi / 6, y: 0, z: 0,  // Swing through ball
            duration: 0.1
        )

        // Follow through: continue motion after hit
        let followThrough = SCNAction.rotateBy(
            x: -CGFloat.pi / 6, y: 0, z: 0,  // Return to neutral
            duration: 0.2
        )

        let sequence = SCNAction.sequence([backswing, downswing, followThrough])
        clubNode.runAction(sequence) {
            completion()
        }
    }

    // MARK: - Hide/Reset

    func hideClub() {
        clubNode.isHidden = true
        previewDotNode.isHidden = true
        ringNode.isHidden = true
        placementPosition = nil
        aimDirection = nil
    }

    func reset() {
        hideClub()
        clubNode.eulerAngles = SCNVector3Zero
    }
}
