import SwiftUI
import SceneKit

struct GameSceneView: UIViewRepresentable {

    let coordinator: GameCoordinator
    @Binding var scnViewBinding: SCNView?

    func makeCoordinator() -> GestureHandler {
        GestureHandler(gameCoordinator: coordinator)
    }

    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.scene = coordinator.sceneManager.scene
        scnView.isPlaying = true
        scnView.antialiasingMode = .multisampling4X
        scnView.backgroundColor = UIColor(red: 0.35, green: 0.58, blue: 0.78, alpha: 1.0)
        scnView.allowsCameraControl = false
        scnView.showsStatistics = false

        context.coordinator.scnView = scnView

        // Expose SCNView to parent
        DispatchQueue.main.async {
            scnViewBinding = scnView
        }

        // One-finger gestures
        let tap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(GestureHandler.handleTap(_:))
        )
        let pan = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(GestureHandler.handlePan(_:))
        )
        pan.minimumNumberOfTouches = 1
        pan.maximumNumberOfTouches = 1

        let swipeLeft = UISwipeGestureRecognizer(
            target: context.coordinator,
            action: #selector(GestureHandler.handleSwipe(_:))
        )
        swipeLeft.direction = .left
        let swipeRight = UISwipeGestureRecognizer(
            target: context.coordinator,
            action: #selector(GestureHandler.handleSwipe(_:))
        )
        swipeRight.direction = .right
        let pinch = UIPinchGestureRecognizer(
            target: context.coordinator,
            action: #selector(GestureHandler.handlePinch(_:))
        )

        // Two-finger gestures
        let twoFingerPan = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(GestureHandler.handleTwoFingerPan(_:))
        )
        twoFingerPan.minimumNumberOfTouches = 2
        twoFingerPan.maximumNumberOfTouches = 2

        let twoFingerTap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(GestureHandler.handleTwoFingerTap(_:))
        )
        twoFingerTap.numberOfTouchesRequired = 2

        pan.require(toFail: swipeLeft)
        pan.require(toFail: swipeRight)
        pan.require(toFail: twoFingerPan)

        scnView.addGestureRecognizer(tap)
        scnView.addGestureRecognizer(pan)
        scnView.addGestureRecognizer(swipeLeft)
        scnView.addGestureRecognizer(swipeRight)
        scnView.addGestureRecognizer(pinch)
        scnView.addGestureRecognizer(twoFingerPan)
        scnView.addGestureRecognizer(twoFingerTap)

        return scnView
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        // Ensure binding stays updated
        if scnViewBinding !== uiView {
            DispatchQueue.main.async {
                scnViewBinding = uiView
            }
        }
    }

    // MARK: - Gesture Handler

    class GestureHandler: NSObject {

        weak var scnView: SCNView?
        let gameCoordinator: GameCoordinator

        private var isAiming = false
        private let minOrthoScale: Double = 1.5
        private let maxOrthoScale: Double = 8.0

        // How close (in screen points) the touch must be to the ball to start aiming
        private let ballTouchRadius: CGFloat = 100.0

        init(gameCoordinator: GameCoordinator) {
            self.gameCoordinator = gameCoordinator
        }

        // MARK: - Tap

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let scnView else { return }
            let location = gesture.location(in: scnView)

            if gameCoordinator.gameState == .editing {
                guard let pos = hitTestEditorPosition(at: location) else { return }
                gameCoordinator.editorController.handleEditorTap(at: pos)
                return
            }

            // No tap actions needed during gameplay (slingshot is all pan-based)
        }

        // MARK: - Pan (Slingshot Aim + Swing)

        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let scnView else { return }
            let location = gesture.location(in: scnView)

            if gameCoordinator.gameState == .editing {
                if gesture.state == .changed || gesture.state == .began {
                    if let pos = hitTestEditorPosition(at: location) {
                        gameCoordinator.editorController.handleEditorDrag(at: pos)
                    }
                }
                return
            }

            guard gameCoordinator.gameState == .playing else { return }
            guard gameCoordinator.turnManager.state == .placingClub else { return }

            switch gesture.state {
            case .began:
                // Check if touch is near the ball
                if isTouchNearBall(location) {
                    isAiming = true
                    updateAimFromTouch(location)
                }

            case .changed:
                if isAiming {
                    updateAimFromTouch(location)
                }

            case .ended, .cancelled:
                if isAiming {
                    let power = powerFromTouch(location)
                    if power > 0.05 {
                        gameCoordinator.fireShot(power: CGFloat(power))
                    } else {
                        gameCoordinator.cancelAim()
                    }
                    isAiming = false
                }

            default: break
            }
        }

        // MARK: - Two-Finger Pan (Camera Manual Control)

        @objc func handleTwoFingerPan(_ gesture: UIPanGestureRecognizer) {
            guard gameCoordinator.gameState == .playing else { return }
            guard let scnView else { return }

            let translation = gesture.translation(in: scnView)
            gesture.setTranslation(.zero, in: scnView)

            // Convert screen delta to world-space delta
            let scale = Float(gameCoordinator.sceneManager.cameraNode.camera?.orthographicScale ?? 6.0)
            let deltaX = Float(translation.x) * scale * 0.002
            let deltaZ = Float(translation.y) * scale * 0.002

            let delta = SCNVector3(-deltaX, 0, deltaZ)
            gameCoordinator.sceneManager.panCameraManually(by: delta)
        }

        // MARK: - Two-Finger Tap (Reset Camera to Ball)

        @objc func handleTwoFingerTap(_ gesture: UITapGestureRecognizer) {
            guard gameCoordinator.gameState == .playing else { return }
            gameCoordinator.sceneManager.resetCameraToBall()
        }

        // MARK: - Swipe (Camera Rotation)

        @objc func handleSwipe(_ gesture: UISwipeGestureRecognizer) {
            guard gameCoordinator.gameState == .playing ||
                  gameCoordinator.gameState == .editing else { return }

            if gesture.direction == .left {
                gameCoordinator.sceneManager.rotateToNextAngle()
            } else {
                gameCoordinator.sceneManager.rotateToPreviousAngle()
            }

            if gameCoordinator.gameState == .editing {
                gameCoordinator.editorController.updateCameraLabel()
            }
        }

        // MARK: - Pinch (Zoom)

        @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            guard gameCoordinator.gameState == .playing ||
                  gameCoordinator.gameState == .editing else { return }
            guard let camera = gameCoordinator.sceneManager.cameraNode.camera else { return }

            if gesture.state == .changed {
                let newScale = camera.orthographicScale / Double(gesture.scale)
                camera.orthographicScale = min(max(newScale, minOrthoScale), maxOrthoScale)
                gesture.scale = 1.0
            }
        }

        // MARK: - Aim Helpers

        /// Check if touch point is close enough to the ball on screen.
        private func isTouchNearBall(_ point: CGPoint) -> Bool {
            guard let scnView else { return false }
            let ballPos = gameCoordinator.ballController.ballNode.position
            let ballScreen = scnView.projectPoint(ballPos)
            let dx = point.x - CGFloat(ballScreen.x)
            let dy = point.y - CGFloat(ballScreen.y)
            return sqrt(dx * dx + dy * dy) < ballTouchRadius
        }

        /// Compute power from screen-space distance between touch and ball.
        private func powerFromTouch(_ point: CGPoint) -> Float {
            guard let scnView else { return 0 }
            let ballPos = gameCoordinator.ballController.ballNode.position
            let ballScreen = scnView.projectPoint(ballPos)
            let dx = point.x - CGFloat(ballScreen.x)
            let dy = point.y - CGFloat(ballScreen.y)
            let screenDist = sqrt(dx * dx + dy * dy)
            return min(Float(screenDist / 200.0), 1.0)
        }

        /// Update aim direction and club position from touch location.
        private func updateAimFromTouch(_ point: CGPoint) {
            guard let angle = angleFromBallToTouch(touchPoint: point) else { return }
            let power = powerFromTouch(point)
            gameCoordinator.updateAim(angle: angle, power: CGFloat(power))
        }

        // MARK: - Hit Testing

        private func hitTestEditorPosition(at point: CGPoint) -> SCNVector3? {
            guard let scnView else { return nil }
            let near = scnView.unprojectPoint(SCNVector3(Float(point.x), Float(point.y), 0))
            let far = scnView.unprojectPoint(SCNVector3(Float(point.x), Float(point.y), 1))

            let dir = simd_float3(far.x - near.x, far.y - near.y, far.z - near.z)
            guard dir.y != 0 else { return nil }

            let t = -near.y / dir.y
            return SCNVector3(near.x + dir.x * t, 0, near.z + dir.z * t)
        }

        // MARK: - Angle Calculation

        /// Compute the world-space angle from ball to the touch point projected onto the ground plane.
        private func angleFromBallToTouch(touchPoint: CGPoint) -> Float? {
            guard let scnView else { return nil }

            // Unproject touch to world Y=0 plane
            let near = scnView.unprojectPoint(SCNVector3(Float(touchPoint.x), Float(touchPoint.y), 0))
            let far = scnView.unprojectPoint(SCNVector3(Float(touchPoint.x), Float(touchPoint.y), 1))

            let dir = simd_float3(far.x - near.x, far.y - near.y, far.z - near.z)
            guard dir.y != 0 else { return nil }

            let t = -near.y / dir.y
            let worldX = near.x + dir.x * t
            let worldZ = near.z + dir.z * t

            let ballPos = gameCoordinator.ballController.ballNode.position
            let dx = worldX - ballPos.x
            let dz = worldZ - ballPos.z
            let dist = sqrt(dx * dx + dz * dz)
            guard dist > 0.05 else { return nil }

            return atan2(dx, dz)
        }
    }
}
