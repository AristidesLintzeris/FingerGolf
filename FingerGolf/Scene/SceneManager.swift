import SceneKit

class SceneManager {

    let scene: SCNScene
    let cameraNode: SCNNode
    let cameraOrbitNode: SCNNode

    private var courseRootNode: SCNNode?

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
        // Directional "sun" light - warm, casts shadows
        let sunNode = SCNNode()
        sunNode.name = "sun_light"
        sunNode.light = SCNLight()
        sunNode.light!.type = .directional
        sunNode.light!.color = UIColor(white: 1.0, alpha: 1.0)
        sunNode.light!.intensity = 1000
        sunNode.light!.castsShadow = true
        sunNode.light!.shadowMode = .deferred
        sunNode.light!.shadowSampleCount = 8
        sunNode.light!.shadowRadius = 3.0
        sunNode.light!.shadowColor = UIColor(white: 0, alpha: 0.3)
        sunNode.eulerAngles = SCNVector3(-Float.pi / 3, Float.pi / 4, 0)
        scene.rootNode.addChildNode(sunNode)

        // Ambient fill light
        let ambientNode = SCNNode()
        ambientNode.name = "ambient_light"
        ambientNode.light = SCNLight()
        ambientNode.light!.type = .ambient
        ambientNode.light!.color = UIColor(red: 0.6, green: 0.65, blue: 0.7, alpha: 1.0)
        ambientNode.light!.intensity = 500
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

    // MARK: - Camera Rotation

    func rotateCameraOrbit(by angle: Float) {
        cameraOrbitNode.eulerAngles.y += angle
    }

    func setCameraOrbitAngle(_ angle: Float) {
        cameraOrbitNode.eulerAngles.y = angle
    }
}
