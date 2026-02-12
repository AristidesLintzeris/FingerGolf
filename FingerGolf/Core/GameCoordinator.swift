import SceneKit
import Combine

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
    let trajectoryPreview = TrajectoryPreview()
    let editorController = EditorController()
    lazy var cloudKitManager = CloudKitManager.shared

    // MARK: - State

    @Published var gameState: GameState = .mainMenu
    @Published var showRestartFade: Bool = false
    @Published var holeScreenPosition: CGPoint = .zero
    @Published var trajectoryPower: Float = 0.0  // For UI trajectory overlay

    private var cancellables = Set<AnyCancellable>()
    private var ballCheckTimer: Timer?
    private var cameraFollowTimer: Timer?

    // MARK: - Init

    init() {
        physicsManager = PhysicsManager(settings: settings)
        holeDetector = HoleDetector(settings: settings)
        physicsManager.delegate = self

        sceneManager.scene.physicsWorld.contactDelegate = physicsManager
    }

    // MARK: - Computed

    var currentPar: Int {
        courseManager.currentCourse?.par ?? 0
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

        // Setup physics for each piece (concave mesh for accurate wood edges)
        for child in courseNode.childNodes {
            physicsManager.setupCoursePiecePhysics(for: child)
        }

        // Add hole trigger
        let holeTrigger = physicsManager.setupHoleTrigger(at: definition.holePosition.scenePosition)
        courseNode.addChildNode(holeTrigger)
        holeDetector.setHolePosition(definition.holePosition.scenePosition)

        // Setup flag physics (ball hitting flag pole = hole complete)
        if let flagNode = courseNode.childNode(withName: "flag", recursively: true) {
            physicsManager.setupFlagPhysics(for: flagNode)
        }

        // Set course in scene
        sceneManager.setCourseRoot(courseNode)

        // Place ball at start
        physicsManager.setupBallPhysics(for: ballController.ballNode)
        ballController.placeBall(at: definition.ballStart.scenePosition)
        sceneManager.scene.rootNode.addChildNode(ballController.ballNode)

        // Switch to perspective follow camera for gameplay
        sceneManager.enablePerspectiveCamera()

        // Start camera tracking
        sceneManager.startFollowingBall(ballController.ballNode)
        sceneManager.centerCamera(on: ballController.ballNode.position)
        startCameraFollow()

        // Add club to scene
        clubController.addToScene(sceneManager.scene.rootNode)

        // Add trajectory preview (3D fallback)
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
        stopCameraFollow()

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
        stopCameraFollow()
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
        stopCameraFollow()
    }

    func unpauseGame() {
        guard gameState == .paused else { return }
        sceneManager.scene.isPaused = false
        startBallMonitoring()
        startCameraFollow()
        gameState = .playing
    }

    func restartCurrentHole() {
        guard let definition = courseManager.currentCourse else { return }
        trajectoryPreview.hide()
        sceneManager.scene.isPaused = false
        stopBallMonitoring()
        stopCameraFollow()

        ballController.placeBall(at: definition.ballStart.scenePosition)
        physicsManager.setupBallPhysics(for: ballController.ballNode)
        clubController.hideClub()
        turnManager.resetForNewHole()
        gameState = .playing

        // Start camera tracking
        sceneManager.startFollowingBall(ballController.ballNode)
        sceneManager.centerCamera(on: ballController.ballNode.position)
        startBallMonitoring()
        startCameraFollow()
    }

    func applySettings() {
        // Settings are applied through direct property access where needed
    }

    // MARK: - Touch Input: Slingshot Aim

    func updateAim(angle: Float, power: CGFloat) {
        guard turnManager.state == .placingClub else { return }
        clubController.showOnRing(
            ballPosition: ballController.ballNode.position,
            angle: angle
        )

        // Update trajectory power for UI overlay
        trajectoryPower = Float(power)

        // Also update 3D trajectory (keeping for fallback)
        if let direction = clubController.aimDirection {
            trajectoryPreview.update(
                ballPosition: ballController.ballNode.position,
                direction: direction,
                power: Float(power)
            )
        }
    }

    func cancelAim() {
        clubController.hideClub()
        trajectoryPreview.hide()
        trajectoryPower = 0.0
    }

    func fireShot(power: CGFloat) {
        guard turnManager.state == .placingClub,
              let direction = clubController.aimDirection else { return }

        trajectoryPreview.hide()
        turnManager.advanceState(.swingStarted)

        let clampedPower = min(max(power, 0.05), 1.0)
        let forceMagnitude = clampedPower * settings.basePower * settings.powerPreset.multiplier

        clubController.playSwingAnimation(power: clampedPower) { [weak self] in
            guard let self else { return }

            let impulse = SCNVector3(
                direction.x * Float(forceMagnitude),
                0.02,
                direction.z * Float(forceMagnitude)
            )
            self.ballController.applyImpulse(impulse)
            self.clubController.hideClub()
            self.turnManager.advanceState(.ballHit)
        }
    }

    // MARK: - Camera Follow

    private func startCameraFollow() {
        cameraFollowTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { [weak self] _ in
            self?.sceneManager.updateCameraFollow()
        }
    }

    private func stopCameraFollow() {
        cameraFollowTimer?.invalidate()
        cameraFollowTimer = nil
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

        // Safety: trigger fade restart if ball falls off course
        if ballController.hasFallenOff {
            handleBallFellOff()
            return
        }

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

    private func handleBallFellOff() {
        stopBallMonitoring()
        stopCameraFollow()

        // Trigger fade effect
        showRestartFade = true

        // After fade completes, restart
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            self?.showRestartFade = false
            self?.restartCurrentHole()
        }
    }

    // MARK: - PhysicsManagerDelegate

    func physicsManager(_ manager: PhysicsManager, ballDidEnterHole ballNode: SCNNode) {
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

    func physicsManager(_ manager: PhysicsManager, ballDidHitFlagPole ballNode: SCNNode) {
        guard turnManager.state == .ballMoving else { return }
        stopBallMonitoring()
        stopCameraFollow()

        let holePos = courseManager.currentCourse?.holePosition.scenePosition ?? SCNVector3Zero
        ballController.captureInHole(holePosition: holePos)
        turnManager.advanceState(.ballStopped)
        turnManager.advanceState(.ballInHole)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.completeHole()
        }
    }

    func physicsManager(_ manager: PhysicsManager, ballDidFallOffCourse ballNode: SCNNode) {
        handleBallFellOff()
    }

    // MARK: - Editor

    func startEditor(course: CourseDefinition? = nil) {
        sceneManager.clearCourse()
        ballController.ballNode.removeFromParentNode()
        clubController.reset()
        trajectoryPreview.hide()

        // Switch to orthographic top-down camera for editor mode
        sceneManager.enableOrthographicCamera()

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
