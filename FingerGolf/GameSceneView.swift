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
        scnView.isPlaying = false  // Start paused; updateUIView enables when gameplay begins
        scnView.antialiasingMode = .multisampling2X
        scnView.backgroundColor = UIColor(red: 0.35, green: 0.58, blue: 0.78, alpha: 1.0)
        scnView.allowsCameraControl = false
        scnView.showsStatistics = false

        context.coordinator.scnView = scnView

        DispatchQueue.main.async {
            scnViewBinding = scnView
        }

        // Tap (editor only)
        let tap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(GestureHandler.handleTap(_:))
        )

        // Pan: aim ball OR orbit camera
        let pan = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(GestureHandler.handlePan(_:))
        )
        pan.minimumNumberOfTouches = 1
        pan.maximumNumberOfTouches = 1

        // Swipe for editor camera rotation
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

        // Pinch zoom (editor only)
        let pinch = UIPinchGestureRecognizer(
            target: context.coordinator,
            action: #selector(GestureHandler.handlePinch(_:))
        )

        scnView.addGestureRecognizer(tap)
        scnView.addGestureRecognizer(pan)
        scnView.addGestureRecognizer(swipeLeft)
        scnView.addGestureRecognizer(swipeRight)
        scnView.addGestureRecognizer(pinch)

        return scnView
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        // Only render the 3D scene during gameplay/editor states — saves GPU on menus
        let shouldRender: Bool
        switch coordinator.gameState {
        case .playing, .paused, .holeComplete, .courseComplete, .failed, .editing:
            shouldRender = true
        case .mainMenu, .courseSelect, .findCourse:
            shouldRender = false
        }
        uiView.isPlaying = shouldRender

        if scnViewBinding !== uiView {
            DispatchQueue.main.async {
                scnViewBinding = uiView
            }
        }
    }

    // MARK: - Gesture Handler (Unity InputManager equivalent)

    class GestureHandler: NSObject {

        weak var scnView: SCNView?
        let gameCoordinator: GameCoordinator

        /// World-space radius multiplier for ball touch detection (scales with zoom)
        private let ballTouchRadiusMultiplier: Float = 3.0

        /// Drag threshold before activating aim mode (prevents jitter)
        private let aimDragThreshold: CGFloat = 15.0

        /// Initial touch location for threshold detection
        private var dragStartLocation: CGPoint?

        /// Decides if this drag controls ball or camera
        private var controlMode: ControlMode = .none

        private enum ControlMode {
            case none
            case ball    // Dragging near ball = aiming
            case camera  // Dragging away from ball = camera orbit
        }

        init(gameCoordinator: GameCoordinator) {
            self.gameCoordinator = gameCoordinator
        }

        // MARK: - Tap (editor only)

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let scnView else { return }
            let location = gesture.location(in: scnView)

            if gameCoordinator.gameState == .editing {
                guard let pos = hitTestGroundPlane(at: location) else { return }
                gameCoordinator.editorController.handleEditorTap(at: pos)
            }
        }

        // MARK: - Pan (aim ball or orbit camera)

        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let scnView else { return }
            let location = gesture.location(in: scnView)

            // Editor mode
            if gameCoordinator.gameState == .editing {
                if gesture.state == .changed || gesture.state == .began {
                    if let pos = hitTestGroundPlane(at: location) {
                        gameCoordinator.editorController.handleEditorDrag(at: pos)
                    }
                }
                return
            }

            guard gameCoordinator.gameState == .playing else { return }

            switch gesture.state {
            case .began:
                // Store initial touch location for threshold detection
                dragStartLocation = location

                // Check if touch is near ball
                if isTouchNearBall(location) && gameCoordinator.ballController.ballIsStatic {
                    // Don't activate aim mode yet - wait for drag threshold
                    controlMode = .ball
                } else {
                    controlMode = .camera
                }

            case .changed:
                switch controlMode {
                case .ball:
                    // CRITICAL: Lock camera during ball aiming - NO camera movement
                    // Check if drag threshold exceeded
                    if let startLoc = dragStartLocation {
                        let dx = location.x - startLoc.x
                        let dy = location.y - startLoc.y
                        let distance = sqrt(dx * dx + dy * dy)

                        if distance >= aimDragThreshold {
                            // Threshold exceeded - activate aiming if not already active
                            if !gameCoordinator.ballController.isAiming {
                                if let worldPoint = hitTestGroundPlane(at: startLoc) {
                                    gameCoordinator.aimBegan(worldPoint: worldPoint)
                                }
                            }
                            dragStartLocation = nil
                        }
                    }

                    // Update aim if active
                    if gameCoordinator.ballController.isAiming {
                        if let worldPoint = hitTestGroundPlane(at: location) {
                            gameCoordinator.aimMoved(worldPoint: worldPoint)
                        }
                    }
                    // NO camera movement in ball mode!

                case .camera:
                    // Camera mode - allow orbit
                    let translation = gesture.translation(in: scnView)
                    gesture.setTranslation(.zero, in: scnView)
                    gameCoordinator.rotateCamera(
                        deltaX: Float(translation.x),
                        deltaY: Float(translation.y)
                    )

                case .none:
                    break
                }

            case .ended, .cancelled:
                dragStartLocation = nil
                if controlMode == .ball {
                    gameCoordinator.aimEnded()
                }
                controlMode = .none

            default:
                break
            }
        }

        // MARK: - Swipe (editor camera rotation)

        @objc func handleSwipe(_ gesture: UISwipeGestureRecognizer) {
            guard gameCoordinator.gameState == .editing else { return }

            if gesture.direction == .left {
                gameCoordinator.sceneManager.rotateToNextAngle()
            } else {
                gameCoordinator.sceneManager.rotateToPreviousAngle()
            }

            gameCoordinator.editorController.updateCameraLabel()
        }

        // MARK: - Pinch (editor zoom)

        @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            if gameCoordinator.gameState == .editing {
                guard let camera = gameCoordinator.sceneManager.cameraNode.camera else { return }
                if gesture.state == .changed {
                    let newScale = camera.orthographicScale / Double(gesture.scale)
                    camera.orthographicScale = min(max(newScale, 1.5), 8.0)
                    gesture.scale = 1.0
                }
            } else if gameCoordinator.gameState == .playing {
                if gesture.state == .changed {
                    gameCoordinator.zoomCamera(scale: Float(gesture.scale))
                    gesture.scale = 1.0
                }
            }
        }

        // MARK: - Helpers

        /// Check if touch is within world-space radius of ball (scales with camera zoom)
        private func isTouchNearBall(_ point: CGPoint) -> Bool {
            guard let scnView else { return false }
            let ballPos = gameCoordinator.ballController.worldPosition

            // Calculate world-space touch radius based on ball size
            let worldRadius: Float = 0.035 * ballTouchRadiusMultiplier

            // Project ball center to screen
            let ballScreen = scnView.projectPoint(ballPos)

            // Project ball + radius to screen to get screen-space radius
            let ballPlusRadius = SCNVector3(ballPos.x + worldRadius, ballPos.y, ballPos.z)
            let radiusScreen = scnView.projectPoint(ballPlusRadius)

            // Calculate screen-space radius
            let screenRadius = sqrt(
                pow(radiusScreen.x - ballScreen.x, 2) +
                pow(radiusScreen.y - ballScreen.y, 2)
            )

            // Check if touch is within radius
            let dx = point.x - CGFloat(ballScreen.x)
            let dy = point.y - CGFloat(ballScreen.y)
            let distance = sqrt(dx * dx + dy * dy)

            return distance < CGFloat(screenRadius)
        }

        /// Unproject screen point to Y=0 ground plane
        private func hitTestGroundPlane(at point: CGPoint) -> SCNVector3? {
            guard let scnView else { return nil }
            let near = scnView.unprojectPoint(SCNVector3(Float(point.x), Float(point.y), 0))
            let far = scnView.unprojectPoint(SCNVector3(Float(point.x), Float(point.y), 1))

            let dir = simd_float3(far.x - near.x, far.y - near.y, far.z - near.z)
            guard dir.y != 0 else { return nil }

            let t = -near.y / dir.y
            return SCNVector3(near.x + dir.x * t, 0, near.z + dir.z * t)
        }
    }
}
