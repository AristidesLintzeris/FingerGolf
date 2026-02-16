import SceneKit

class SceneManager {

    let scene = SCNScene()
    let cameraNode = SCNNode()
    let cameraOrbitNode = SCNNode()
    private(set) var courseRootNode: SCNNode?

    // Camera follow target (the ball)
    private var followTarget: SCNNode?

    // 3rd person orbit camera (gameplay)
    private var cameraYaw: Float = 0        // Horizontal angle (radians)
    private var cameraPitch: Float = 30     // Elevation angle (degrees above horizontal)
    private var cameraDistance: Float = 5.0
    private let cameraDistanceMin: Float = 2.5
    private let cameraDistanceMax: Float = 10.0
    private let pitchMin: Float = 15
    private let pitchMax: Float = 75
    let rotationSpeed: Float = 0.3

    // Smooth follow interpolation
    private let followSmoothFactor: Float = 0.15

    // Editor mode discrete angles + orthographic
    private var currentAngleIndex = 0
    private let isometricAngles: [Float] = [
        Float.pi / 4,
        Float.pi * 3 / 4,
        Float.pi * 5 / 4,
        Float.pi * 7 / 4
    ]

    init() {
        setupCamera()
        setupLighting()
    }

    // MARK: - Camera Setup

    private func setupCamera() {
        let camera = SCNCamera()
        camera.usesOrthographicProjection = false
        camera.fieldOfView = 60
        camera.zNear = 0.1
        camera.zFar = 100
        cameraNode.camera = camera

        // Default: will be repositioned by orbit system
        cameraNode.position = SCNVector3(0, 4, 6)
        cameraNode.eulerAngles.x = -.pi / 6

        cameraOrbitNode.addChildNode(cameraNode)
        scene.rootNode.addChildNode(cameraOrbitNode)
    }

    // MARK: - Camera Modes

    /// Set up perspective camera for gameplay (3rd person orbit)
    func enablePerspectiveCamera() {
        guard let camera = cameraNode.camera else { return }

        camera.usesOrthographicProjection = false
        camera.fieldOfView = 60

        // Reset orbit to default view
        cameraYaw = 0
        cameraPitch = 30
        cameraDistance = 5.0
        updateCameraNodePosition()
    }

    /// Switch to orthographic top-down camera for editor mode
    func enableOrthographicCamera() {
        guard let camera = cameraNode.camera else { return }

        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.3

        camera.usesOrthographicProjection = true
        camera.orthographicScale = 6.0

        cameraNode.eulerAngles.x = -.pi / 3
        cameraNode.position = SCNVector3(0, 18, 6)
        cameraOrbitNode.eulerAngles.y = isometricAngles[currentAngleIndex]

        SCNTransaction.commit()
    }

    private func setupLighting() {
        // Ambient light: baseline illumination for all surfaces
        let ambientNode = SCNNode()
        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.color = UIColor(white: 0.80, alpha: 1.0)
        ambientNode.light = ambient
        scene.rootNode.addChildNode(ambientNode)

        // Key light (sun): primary directional light casting shadows
        let sunNode = SCNNode()
        let sun = SCNLight()
        sun.type = .directional
        sun.color = UIColor(white: 0.6, alpha: 1.0)
        sun.castsShadow = true
        sun.shadowMode = .deferred
        sun.shadowSampleCount = 8
        sun.shadowRadius = 8
        sun.shadowMapSize = CGSize(width: 1024, height: 1024)
        sun.shadowColor = UIColor(white: 0, alpha: 0.4)  // Semi-transparent shadows
        sun.maximumShadowDistance = 30
        sun.orthographicScale = 10
        sunNode.light = sun
        sunNode.eulerAngles = SCNVector3(-Float.pi / 3, Float.pi / 4, 0)
        scene.rootNode.addChildNode(sunNode)

        // Fill light: softer directional from opposite the sun to reduce shadow harshness
        let fillNode = SCNNode()
        let fill = SCNLight()
        fill.type = .directional
        fill.color = UIColor(white: 0.3, alpha: 1.0)
        fill.castsShadow = false
        fillNode.light = fill
        fillNode.eulerAngles = SCNVector3(-Float.pi / 4.5, -Float.pi * 3 / 4, 0)
        scene.rootNode.addChildNode(fillNode)
    }

    // MARK: - Course Management

    func setCourseRoot(_ node: SCNNode) {
        clearCourse()
        courseRootNode = node
        scene.rootNode.addChildNode(node)
    }

    func clearCourse() {
        courseRootNode?.removeFromParentNode()
        courseRootNode = nil
        followTarget = nil
    }

    // MARK: - Camera Follow

    func setFollowTarget(_ target: SCNNode) {
        followTarget = target
    }

    /// Called every frame to smoothly follow the ball
    func updateCameraFollow() {
        guard let target = followTarget else { return }
        // Use presentation position to track actual physics-simulated position
        let pos = target.presentation.position
        let tx = pos.x
        let tz = pos.z

        // Smooth interpolation toward target position
        let cx = cameraOrbitNode.position.x + (tx - cameraOrbitNode.position.x) * followSmoothFactor
        let cz = cameraOrbitNode.position.z + (tz - cameraOrbitNode.position.z) * followSmoothFactor
        cameraOrbitNode.position = SCNVector3(cx, 0, cz)
    }

    /// Snap camera to ball position immediately (no interpolation)
    func snapCameraToBall() {
        guard let target = followTarget else { return }
        let pos = target.presentation.position
        cameraOrbitNode.position = SCNVector3(pos.x, 0, pos.z)
        updateCameraNodePosition()
    }

    // MARK: - Camera Orbit (3rd person gameplay)

    /// Orbit camera around ball. deltaX = horizontal screen movement, deltaY = vertical.
    func orbitCamera(deltaX: Float, deltaY: Float) {
        // Horizontal: rotate around ball (yaw)
        cameraYaw -= deltaX * rotationSpeed * (.pi / 180.0)

        // Vertical: change elevation angle (pitch)
        // Drag up on screen = raise camera (increase pitch)
        cameraPitch += deltaY * rotationSpeed * 0.3
        cameraPitch = max(pitchMin, min(pitchMax, cameraPitch))

        updateCameraNodePosition()
    }

    /// Zoom camera in/out by pinch scale factor
    func zoomCamera(by scale: Float) {
        cameraDistance /= scale
        cameraDistance = max(cameraDistanceMin, min(cameraDistanceMax, cameraDistance))
        updateCameraNodePosition()
    }

    /// Legacy method for backward compatibility
    func rotateCamera(byScreenDelta deltaX: Float) {
        orbitCamera(deltaX: deltaX, deltaY: 0)
    }

    /// Position camera using spherical coordinates around orbit center
    private func updateCameraNodePosition() {
        let pitchRad = cameraPitch * .pi / 180.0
        let height = cameraDistance * sin(pitchRad)
        let distance = cameraDistance * cos(pitchRad)

        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0
        SCNTransaction.disableActions = true

        cameraNode.position = SCNVector3(0, height, distance)
        cameraNode.eulerAngles.x = -pitchRad
        cameraOrbitNode.eulerAngles.y = cameraYaw

        SCNTransaction.commit()
    }

    // MARK: - Editor Camera (discrete angles, orthographic)

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
