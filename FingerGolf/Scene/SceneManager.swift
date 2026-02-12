import SceneKit

class SceneManager {

    let scene = SCNScene()
    let cameraNode = SCNNode()
    let cameraOrbitNode = SCNNode()
    private(set) var courseRootNode: SCNNode?

    private var currentAngleIndex = 0
    private let isometricAngles: [Float] = [
        Float.pi / 4,           // NE corner (45°)
        Float.pi * 3 / 4,       // SE corner (135°)
        Float.pi * 5 / 4,       // SW corner (225°)
        Float.pi * 7 / 4        // NW corner (315°)
    ]

    // Camera follow settings
    private var followingBall: SCNNode?
    private var manualCameraOffset: SCNVector3 = SCNVector3Zero
    private var isManuallyControlled = false

    init() {
        setupCamera()
        setupLighting()
    }

    // MARK: - Camera Setup

    private func setupCamera() {
        let camera = SCNCamera()

        // Start with perspective camera for gameplay (Unity-like follow camera)
        camera.usesOrthographicProjection = false
        camera.fieldOfView = 60  // Standard 60° FOV
        camera.zNear = 0.1
        camera.zFar = 100
        cameraNode.camera = camera

        // Perspective camera position: behind and above the ball for follow view
        let followPitch: Float = -.pi / 6  // 30° down (gentle angle)
        let followHeight: Float = 3.0  // Height above ground
        let followDistance: Float = 4.0  // Distance back from target

        cameraNode.eulerAngles.x = followPitch
        cameraNode.position = SCNVector3(0, followHeight, followDistance)

        cameraOrbitNode.addChildNode(cameraNode)
        scene.rootNode.addChildNode(cameraOrbitNode)

        // Start at first corner angle
        setCameraAngleIndex(0)
    }

    // MARK: - Camera Mode Switching

    /// Switch to perspective follow camera for gameplay (Unity-like)
    func enablePerspectiveCamera() {
        guard let camera = cameraNode.camera else { return }

        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.3

        camera.usesOrthographicProjection = false
        camera.fieldOfView = 60

        // Position camera behind and above for follow view
        cameraNode.eulerAngles.x = -.pi / 6  // 30° down
        cameraNode.position = SCNVector3(0, 3.0, 4.0)

        SCNTransaction.commit()
    }

    /// Switch to orthographic top-down camera for editor mode
    func enableOrthographicCamera() {
        guard let camera = cameraNode.camera else { return }

        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.3

        camera.usesOrthographicProjection = true
        camera.orthographicScale = 6.0

        // Top-down isometric view for editor
        cameraNode.eulerAngles.x = -.pi / 3  // 60° down (steep)
        cameraNode.position = SCNVector3(0, 18, 6)

        SCNTransaction.commit()
    }

    private func setupLighting() {
        // Brighter ambient light for softer shadows
        let ambientNode = SCNNode()
        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.color = UIColor(white: 0.75, alpha: 1.0)
        ambientNode.light = ambient
        scene.rootNode.addChildNode(ambientNode)

        // Directional light (sun) with softer shadows
        let sunNode = SCNNode()
        let sun = SCNLight()
        sun.type = .directional
        sun.color = UIColor(white: 0.6, alpha: 1.0)
        sun.castsShadow = true
        sun.shadowMode = .deferred
        sun.shadowSampleCount = 16
        sun.shadowRadius = 8
        sun.shadowMapSize = CGSize(width: 2048, height: 2048)
        sun.maximumShadowDistance = 30
        sun.orthographicScale = 10
        sunNode.light = sun
        sunNode.eulerAngles = SCNVector3(-Float.pi / 3, Float.pi / 4, 0)
        scene.rootNode.addChildNode(sunNode)
    }

    // MARK: - Course Management

    func setCourseRoot(_ node: SCNNode) {
        clearCourse()
        courseRootNode = node
        scene.rootNode.addChildNode(node)

        // Auto-adjust orthographic scale based on course size
        let bounds = node.boundingBox
        let width = bounds.max.x - bounds.min.x
        let depth = bounds.max.z - bounds.min.z
        let maxDimension = max(width, depth)
        cameraNode.camera?.orthographicScale = Double(maxDimension * 0.8)
    }

    func clearCourse() {
        courseRootNode?.removeFromParentNode()
        courseRootNode = nil
        followingBall = nil
        isManuallyControlled = false
        manualCameraOffset = SCNVector3Zero
    }

    // MARK: - Camera Follow Ball

    func startFollowingBall(_ ballNode: SCNNode) {
        followingBall = ballNode
        isManuallyControlled = false
        manualCameraOffset = SCNVector3Zero
    }

    func updateCameraFollow() {
        guard let ball = followingBall, !isManuallyControlled else { return }
        let targetPos = ball.position
        centerCamera(on: targetPos, animated: false)
    }

    func centerCamera(on position: SCNVector3, animated: Bool = true) {
        let targetPos = SCNVector3(
            position.x + manualCameraOffset.x,
            0,
            position.z + manualCameraOffset.z
        )

        if animated {
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.3
            cameraOrbitNode.position = targetPos
            SCNTransaction.commit()
        } else {
            cameraOrbitNode.position = targetPos
        }
    }

    // MARK: - Manual Camera Control (Two-Finger)

    func panCameraManually(by delta: SCNVector3) {
        isManuallyControlled = true
        manualCameraOffset.x += delta.x
        manualCameraOffset.z += delta.z

        if let ball = followingBall {
            centerCamera(on: ball.position, animated: false)
        }
    }

    func resetCameraToBall() {
        isManuallyControlled = false
        manualCameraOffset = SCNVector3Zero
        if let ball = followingBall {
            centerCamera(on: ball.position, animated: true)
        }
    }

    // MARK: - Camera Rotation

    func rotateToNextAngle() {
        currentAngleIndex = (currentAngleIndex + 1) % isometricAngles.count
        applyCameraRotation()
    }

    func rotateToPreviousAngle() {
        currentAngleIndex = (currentAngleIndex - 1 + isometricAngles.count) % isometricAngles.count
        applyCameraRotation()
    }

    func setCameraAngleIndex(_ index: Int) {
        currentAngleIndex = index % isometricAngles.count
        applyCameraRotation()
    }

    func getCurrentAngleIndex() -> Int {
        return currentAngleIndex
    }

    private func applyCameraRotation() {
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.3
        cameraOrbitNode.eulerAngles.y = isometricAngles[currentAngleIndex]
        SCNTransaction.commit()
    }
}
