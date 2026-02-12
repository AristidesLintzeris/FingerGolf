import SceneKit
import Combine
import AVFoundation

class GameCoordinator: ObservableObject, PhysicsManagerDelegate {

    // MARK: - Child Components

    let sceneManager = SceneManager()
    let courseManager = CourseManager()
    let settings = GameSettings()
    let progressManager = ProgressManager()
    let turnManager = TurnManager()
    let scoringManager = ScoringManager()
    let ballController = BallController(color: "red")
    let clubController = ClubController(color: "red")

    private(set) var physicsManager: PhysicsManager!
    private(set) var holeDetector: HoleDetector!
    private let barrierRipple = BarrierRippleEffect()
    let trajectoryPreview = TrajectoryPreview()
    let editorController = EditorController()
    lazy var cloudKitManager = CloudKitManager.shared

    // Hand tracking components
    let cameraManager = CameraManager()
    private(set) var visionEngine: VisionEngine!
    private(set) var handTrackingCoordinator: HandTrackingCoordinator!
    private(set) var swingDetector: SwingDetector!

    // MARK: - State

    @Published var gameState: GameState = .mainMenu
    @Published var handTrackingEnabled = false
    @Published var cameraPermissionDenied = false
    private var cancellables = Set<AnyCancellable>()
    private var ballCheckTimer: Timer?

    // MARK: - Init

    init() {
        physicsManager = PhysicsManager(settings: settings)
        holeDetector = HoleDetector(settings: settings)
        physicsManager.delegate = self

        sceneManager.scene.physicsWorld.contactDelegate = physicsManager

        // Setup hand tracking pipeline
        visionEngine = VisionEngine(pixelBufferPublisher: cameraManager.pixelBufferPublisher.eraseToAnyPublisher())
        handTrackingCoordinator = HandTrackingCoordinator(visionEngine: visionEngine)
        swingDetector = SwingDetector(handTrackingCoordinator: handTrackingCoordinator)

        observeHandTracking()
    }

    // MARK: - Hand Tracking

    var currentPar: Int {
        courseManager.currentCourse?.par ?? 0
    }

    func startHandTracking() {
        cameraManager.requestPermission()
        cameraManager.$permissionGranted
            .receive(on: RunLoop.main)
            .sink { [weak self] granted in
                guard let self else { return }
                if granted {
                    self.cameraManager.startSession()
                    self.handTrackingEnabled = true
                    self.cameraPermissionDenied = false
                } else if AVCaptureDevice.authorizationStatus(for: .video) == .denied {
                    self.cameraPermissionDenied = true
                }
            }
            .store(in: &cancellables)
    }

    func stopHandTracking() {
        cameraManager.stopSession()
        handTrackingEnabled = false
    }

    private func observeHandTracking() {
        // React to hand flick completion for swing
        handTrackingCoordinator.$handState
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                guard let self else { return }

                switch state {
                case .flickCompleted(let power):
                    if self.turnManager.state == .readyToSwing {
                        self.handleSwing(power: power)
                        self.handTrackingCoordinator.resetForNewSwing()
                    }
                case .pinching:
                    if self.turnManager.state == .readyToSwing,
                       let direction = self.clubController.aimDirection {
                        self.trajectoryPreview.update(
                            ballPosition: self.ballController.ballNode.position,
                            aimDirection: direction,
                            power: 0.3,
                            maxSwingPower: Float(self.settings.maxSwingPower),
                            bright: false
                        )
                    }
                case .flickInProgress:
                    if self.turnManager.state == .readyToSwing,
                       let direction = self.clubController.aimDirection {
                        self.trajectoryPreview.update(
                            ballPosition: self.ballController.ballNode.position,
                            aimDirection: direction,
                            power: 0.7,
                            maxSwingPower: Float(self.settings.maxSwingPower),
                            bright: true
                        )
                    }
                case .noHand:
                    if self.turnManager.state == .readyToSwing {
                        self.turnManager.advanceState(.handLost)
                        self.clubController.hideClub()
                        self.trajectoryPreview.hide()
                    }
                default:
                    break
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Game Flow

    func startCourse(at index: Int? = nil) {
        if let index = index {
            courseManager.currentCourseIndex = index
        }

        guard let definition = courseManager.currentCourse else { return }

        // Clear previous course
        sceneManager.clearCourse()

        // Build and display course
        guard let courseNode = courseManager.buildCurrentCourse() else { return }

        // Setup physics for each piece
        for child in courseNode.childNodes {
            physicsManager.setupCoursePiecePhysics(for: child)
        }

        // Add hole trigger
        let holeTrigger = physicsManager.setupHoleTrigger(at: definition.holePosition.scenePosition)
        courseNode.addChildNode(holeTrigger)
        holeDetector.setHolePosition(definition.holePosition.scenePosition)

        // Add barriers
        let barriers = physicsManager.setupBarriers(around: courseNode)
        for barrier in barriers {
            courseNode.addChildNode(barrier)
        }

        // Set course in scene
        sceneManager.setCourseRoot(courseNode)

        // Place ball at start
        physicsManager.setupBallPhysics(for: ballController.ballNode)
        ballController.placeBall(at: definition.ballStart.scenePosition)
        sceneManager.scene.rootNode.addChildNode(ballController.ballNode)

        // Add club to scene
        clubController.addToScene(sceneManager.scene.rootNode)

        // Add trajectory preview
        trajectoryPreview.addToScene(sceneManager.scene.rootNode)

        // Reset turn
        turnManager.resetForNewHole()
        gameState = .playing

        // Start monitoring ball state
        startBallMonitoring()
    }

    func completeHole() {
        guard let definition = courseManager.currentCourse else { return }

        trajectoryPreview.hide()
        stopBallMonitoring()
        scoringManager.recordHoleScore(par: definition.par, strokes: turnManager.strokeCount)

        progressManager.completeLevel(
            courseManager.currentCourseIndex,
            strokes: turnManager.strokeCount,
            par: definition.par
        )

        if courseManager.hasNextCourse {
            gameState = .holeComplete
        } else {
            gameState = .courseComplete
        }
    }

    func advanceToNextHole() {
        if courseManager.advanceToNextCourse() {
            startCourse()
        } else {
            gameState = .courseComplete
        }
    }

    func returnToMenu() {
        trajectoryPreview.hide()
        stopBallMonitoring()
        sceneManager.scene.isPaused = false
        sceneManager.clearCourse()
        ballController.ballNode.removeFromParentNode()
        clubController.reset()
        courseManager.resetToFirstCourse()
        scoringManager.reset()
        turnManager.resetForNewHole()
        gameState = .mainMenu
    }

    func showLevelSelect() {
        gameState = .courseSelect
    }

    func pauseGame() {
        guard gameState == .playing else { return }
        gameState = .paused
        sceneManager.scene.isPaused = true
        stopBallMonitoring()
    }

    func unpauseGame() {
        guard gameState == .paused else { return }
        sceneManager.scene.isPaused = false
        startBallMonitoring()
        gameState = .playing
    }

    func restartCurrentHole() {
        guard let definition = courseManager.currentCourse else { return }
        trajectoryPreview.hide()
        sceneManager.scene.isPaused = false
        stopBallMonitoring()

        ballController.placeBall(at: definition.ballStart.scenePosition)
        physicsManager.setupBallPhysics(for: ballController.ballNode)
        clubController.hideClub()
        turnManager.resetForNewHole()
        gameState = .playing
        startBallMonitoring()
    }

    func applySettings() {
        handTrackingCoordinator.pinchThreshold = settings.pinchThreshold
        handTrackingCoordinator.flickMinVelocity = settings.flickMinVelocity
        handTrackingCoordinator.powerPreset = settings.powerPreset
        handTrackingCoordinator.updateKalman(q: settings.kalmanProcessNoise, r: settings.kalmanMeasurementNoise)
        visionEngine.smoothingFactor = settings.smoothingFactor
        visionEngine.jumpThreshold = settings.jumpThreshold
    }

    // MARK: - Touch Input (temporary, replaced by hand tracking later)

    func handleClubPlacement(at worldPosition: SCNVector3) {
        guard turnManager.state == .placingClub else { return }
        clubController.positionClub(at: worldPosition)
        turnManager.advanceState(.clubPlaced)
    }

    func handleAimUpdate(toward worldPosition: SCNVector3) {
        guard turnManager.state == .readyToSwing else { return }
        clubController.updateAimDirection(toward: worldPosition)

        // Update trajectory preview (dim while aiming)
        if let direction = clubController.aimDirection {
            trajectoryPreview.update(
                ballPosition: ballController.ballNode.position,
                aimDirection: direction,
                power: 0.5,
                maxSwingPower: Float(settings.maxSwingPower),
                bright: false
            )
        }
    }

    func handleSwing(power: CGFloat) {
        guard turnManager.state == .readyToSwing,
              let direction = clubController.aimDirection else { return }

        trajectoryPreview.hide()
        turnManager.advanceState(.swingStarted)

        let clampedPower = min(max(power, 0.05), 1.0)
        let forceMagnitude = clampedPower * settings.maxSwingPower

        clubController.playSwingAnimation(power: clampedPower) { [weak self] in
            guard let self else { return }

            let forceVector = SCNVector3(
                direction.x * Float(forceMagnitude),
                0.02,
                direction.z * Float(forceMagnitude)
            )
            self.ballController.applyForce(direction: forceVector, power: 1.0)
            self.clubController.hideClub()
            self.turnManager.advanceState(.ballHit)
        }
    }

    // MARK: - Ball Monitoring

    private func startBallMonitoring() {
        ballCheckTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.checkBallState()
        }
    }

    private func stopBallMonitoring() {
        ballCheckTimer?.invalidate()
        ballCheckTimer = nil
    }

    private func checkBallState() {
        guard turnManager.state == .ballMoving else { return }

        ballController.updateState()

        if ballController.state == .atRest {
            turnManager.advanceState(.ballStopped)

            // Check if ball is in hole area
            if holeDetector.shouldCaptureBall(ballController.ballNode) {
                let holePos = courseManager.currentCourse?.holePosition.scenePosition ?? SCNVector3Zero
                ballController.captureInHole(holePosition: holePos)
                turnManager.advanceState(.ballInHole)

                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                    self?.completeHole()
                }
            } else {
                // Ball stopped but not in hole - continue playing
                turnManager.advanceState(.continuePlay)
            }
        }
    }

    // MARK: - PhysicsManagerDelegate

    func physicsManager(_ manager: PhysicsManager, ballDidEnterHole ballNode: SCNNode) {
        // Additional check via physics contact - if ball is slow enough, capture it
        if holeDetector.shouldCaptureBall(ballNode) && turnManager.state == .ballMoving {
            let holePos = courseManager.currentCourse?.holePosition.scenePosition ?? SCNVector3Zero
            ballController.captureInHole(holePosition: holePos)
            turnManager.advanceState(.ballStopped)
            turnManager.advanceState(.ballInHole)

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.completeHole()
            }
        }
    }

    func physicsManager(_ manager: PhysicsManager, ballDidHitBarrier contact: SCNPhysicsContact) {
        barrierRipple.triggerRipple(at: contact.contactPoint, in: sceneManager.scene)
    }

    // MARK: - Editor

    func startEditor(course: CourseDefinition? = nil) {
        sceneManager.clearCourse()
        ballController.ballNode.removeFromParentNode()
        clubController.reset()
        trajectoryPreview.hide()

        editorController.sceneManager = sceneManager
        sceneManager.scene.rootNode.addChildNode(editorController.editorRootNode)

        if let course = course {
            editorController.loadCourse(course)
        }

        sceneManager.cameraOrbitNode.position = SCNVector3(0, 0, 0)
        sceneManager.cameraNode.camera?.orthographicScale = 6.0
        sceneManager.setCameraAngleIndex(0)
        editorController.updateCameraLabel()

        gameState = .editing
    }

    func saveEditorCourse() -> UserCourse? {
        let definition = editorController.toCourseDefinition()
        guard !definition.pieces.isEmpty else { return nil }

        let userCourse = UserCourse(definition: definition)
        try? UserCourseStorage.shared.save(userCourse)
        return userCourse
    }

    func testEditorCourse() {
        let definition = editorController.toCourseDefinition()
        guard !definition.pieces.isEmpty else { return }

        editorController.editorRootNode.removeFromParentNode()

        courseManager.appendCourse(definition)
        let testIndex = courseManager.courses.count - 1
        startCourse(at: testIndex)
    }

    func exitEditor() {
        editorController.clearAll()
        editorController.editorRootNode.removeFromParentNode()
        gameState = .mainMenu
    }

    // MARK: - Community

    private(set) var currentCommunityRecordID: String?

    func showFindCourse() {
        gameState = .findCourse
    }

    func playCommunityLevel(_ userCourse: UserCourse) {
        currentCommunityRecordID = userCourse.cloudRecordID
        courseManager.appendCourse(userCourse.definition)
        let index = courseManager.courses.count - 1
        startCourse(at: index)
    }
}
