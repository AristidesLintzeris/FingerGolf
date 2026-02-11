import SceneKit

class SceneManager {

    let scene: SCNScene
    let cameraNode: SCNNode
    let cameraOrbitNode: SCNNode

    private var courseRootNode: SCNNode?

    // 4 fixed isometric angles: NE, SE, SW, NW
    private let isometricAngles: [Float] = [
        0,                      // NE
        Float.pi / 2,           // SE
        Float.pi,               // SW
        Float.pi * 3 / 2        // NW
    ]
    private(set) var currentAngleIndex: Int = 0

    init() {
        scene = SCNScene()

        // Camera orbit node: rotates around the course center
        cameraOrbitNode = SCNNode()
        cameraOrbitNode.name = "camera_orbit"

        // Camera node: positioned for isometric view
        cameraNode = SCNNode()
        cameraNode.name = "main_camera"
        cameraNode.camera = SCNCamera()
        cameraNode.camera!.usesOrthographicProjection = true
        cameraNode.camera!.orthographicScale = 4.0
        cameraNode.camera!.zNear = 0.1
        cameraNode.camera!.zFar = 100

        // True isometric angle: arctan(1/sqrt(2)) = ~35.264 degrees elevation
        // Position camera elevated and at an angle
        cameraNode.position = SCNVector3(0, 10, 10)
        cameraNode.eulerAngles.x = -Float.pi / 5  // ~36 degrees down

        cameraOrbitNode.addChildNode(cameraNode)
        scene.rootNode.addChildNode(cameraOrbitNode)

        setupLighting()
        setupPhysicsWorld()
        setupBackground()
    }

    // MARK: - Lighting

    private func setupLighting() {
        // Top-down directional light - looks good from all 4 angles
        let sunNode = SCNNode()
        sunNode.name = "sun_light"
        sunNode.light = SCNLight()
        sunNode.light!.type = .directional
        sunNode.light!.color = UIColor(white: 1.0, alpha: 1.0)
        sunNode.light!.intensity = 800
        sunNode.light!.castsShadow = true
        sunNode.light!.shadowMode = .deferred
        sunNode.light!.shadowSampleCount = 8
        sunNode.light!.shadowRadius = 3.0
        sunNode.light!.shadowColor = UIColor(white: 0, alpha: 0.25)
        // Nearly top-down so shadows are short and consistent from all angles
        sunNode.eulerAngles = SCNVector3(-Float.pi / 2.5, 0, 0)
        scene.rootNode.addChildNode(sunNode)

        // Strong ambient fill so no dark sides from any angle
        let ambientNode = SCNNode()
        ambientNode.name = "ambient_light"
        ambientNode.light = SCNLight()
        ambientNode.light!.type = .ambient
        ambientNode.light!.color = UIColor(red: 0.75, green: 0.78, blue: 0.82, alpha: 1.0)
        ambientNode.light!.intensity = 600
        scene.rootNode.addChildNode(ambientNode)
    }

    // MARK: - Physics

    private func setupPhysicsWorld() {
        scene.physicsWorld.gravity = SCNVector3(0, -9.8, 0)
        scene.physicsWorld.speed = 1.0
    }

    // MARK: - Background

    private func setupBackground() {
        // Create a gradient image for the scene background
        let size = CGSize(width: 1, height: 256)
        UIGraphicsBeginImageContextWithOptions(size, true, 1)
        guard let ctx = UIGraphicsGetCurrentContext() else { return }

        let colors = [
            UIColor(red: 0.50, green: 0.75, blue: 0.92, alpha: 1.0).cgColor,
            UIColor(red: 0.35, green: 0.58, blue: 0.78, alpha: 1.0).cgColor
        ]
        let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: nil)!
        ctx.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])

        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        scene.background.contents = image
    }

    // MARK: - Course Management

    func setCourseRoot(_ courseNode: SCNNode) {
        courseRootNode?.removeFromParentNode()
        courseRootNode = courseNode
        scene.rootNode.addChildNode(courseNode)

        // Center camera on course
        let (minBound, maxBound) = courseNode.boundingBox
        let centerX = (minBound.x + maxBound.x) / 2
        let centerZ = (minBound.z + maxBound.z) / 2
        cameraOrbitNode.position = SCNVector3(centerX, 0, centerZ)

        // Adjust orthographic scale to fit course
        let width = maxBound.x - minBound.x
        let depth = maxBound.z - minBound.z
        let maxExtent = max(width, depth)
        cameraNode.camera!.orthographicScale = Double(maxExtent) * 0.8
    }

    func clearCourse() {
        courseRootNode?.removeFromParentNode()
        courseRootNode = nil
    }

    // MARK: - Camera Rotation (4 fixed isometric angles)

    func rotateToNextAngle() {
        currentAngleIndex = (currentAngleIndex + 1) % 4
        animateToCurrentAngle()
    }

    func rotateToPreviousAngle() {
        currentAngleIndex = (currentAngleIndex + 3) % 4
        animateToCurrentAngle()
    }

    private func animateToCurrentAngle() {
        let targetAngle = isometricAngles[currentAngleIndex]
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.35
        SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        cameraOrbitNode.eulerAngles.y = targetAngle
        SCNTransaction.commit()
    }

    func setCameraAngleIndex(_ index: Int) {
        currentAngleIndex = index % 4
        cameraOrbitNode.eulerAngles.y = isometricAngles[currentAngleIndex]
    }
}
