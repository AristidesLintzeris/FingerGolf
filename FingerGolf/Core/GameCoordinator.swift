import SceneKit
import Combine

/// Central coordinator combining Unity's GameManager + LevelManager + InputManager logic.
/// Manages game state, level spawning, shot counting, and win/fail conditions.
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
    let editorController = EditorController()
    lazy var cloudKitManager = CloudKitManager.shared
    let audioManager = AudioManager.shared

    // MARK: - State (Unity: GameManager.gameStatus)

    @Published var gameState: GameState = .mainMenu
    @Published var showRestartFade: Bool = false
    @Published var powerBarFill: Float = 0.0  // Unity: UIManager.PowerBar.fillAmount

    private var gameLoopTimer: Timer?  // Single timer for both camera follow and ball state checking

    // MARK: - Init

    init() {
        physicsManager = PhysicsManager()
        holeDetector = HoleDetector(settings: settings)
        physicsManager.delegate = self
        sceneManager.scene.physicsWorld.contactDelegate = physicsManager
    }

    // MARK: - Computed

    var currentPar: Int {
        courseManager.currentCourse?.par ?? 0
    }

    // MARK: - Game Flow (Unity: LevelManager.SpawnLevel)

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

        // Add hole trigger (Unity: "Hole" trigger collider)
        let holeTrigger = physicsManager.setupHoleTrigger(at: definition.holePosition.scenePosition)
        courseNode.addChildNode(holeTrigger)
        holeDetector.setHolePosition(definition.holePosition.scenePosition)

        // Setup flag physics
        if let flagNode = courseNode.childNode(withName: "flag", recursively: true) {
            physicsManager.setupFlagPhysics(for: flagNode)
        }

        // Set course in scene
        sceneManager.setCourseRoot(courseNode)

        // Place ball at start (Unity: Instantiate ballPrefab at ballSpawnPos)
        physicsManager.setupBallPhysics(for: ballController.ballNode)
        ballController.placeBall(at: definition.ballStart.scenePosition)
        sceneManager.scene.rootNode.addChildNode(ballController.ballNode)
        sceneManager.scene.rootNode.addChildNode(ballController.areaAffectorNode)

        // Switch to perspective camera and start following ball
        // Unity: CameraFollow.SetTarget(ball)
        sceneManager.enablePerspectiveCamera()
        sceneManager.setFollowTarget(ballController.ballNode)
        sceneManager.snapCameraToBall()

        // Add aim line to scene
        clubController.addToScene(sceneManager.scene.rootNode)

        // Reset turn manager with this level's shot count
        // Unity: shotCount = levelDatas[levelIndex].shotCount
        turnManager.resetForNewHole(maxShots: definition.shotCount)

        // Set game status to Playing (Unity: GameManager.gameStatus = GameStatus.Playing)
        gameState = .playing
        powerBarFill = 0

        // Start game loop (combines Unity's Update + LateUpdate)
        startGameLoop()
    }

    // MARK: - Level Complete (Unity: LevelManager.LevelComplete)

    func levelComplete() {
        guard gameState == .playing else { return }
        guard let definition = courseManager.currentCourse else { return }

        stopGameLoop()
        audioManager.ballInHole()

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

    // MARK: - Level Failed (Unity: LevelManager.LevelFailed)

    func levelFailed() {
        guard gameState == .playing else { return }
        stopGameLoop()
        audioManager.ballFellOff()
        gameState = .failed
    }

    // MARK: - Shot Handling

    /// Called when ball stops after a shot.
    /// Unity: BallControl.Update detects velocity==zero -> LevelManager.ShotTaken()
    private func onBallStopped() {
        let shotsRemain = turnManager.shotTaken()

        // Check if ball is close to hole
        if holeDetector.shouldCaptureBall(ballController.ballNode) {
            let holePos = courseManager.currentCourse?.holePosition.scenePosition ?? SCNVector3Zero
            ballController.captureInHole(holePosition: holePos)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.levelComplete()
            }
            return
        }

        // Unity: if shotCount <= 0 -> LevelFailed()
        if !shotsRemain {
            levelFailed()
        }
    }

    // MARK: - Input: Aiming (Unity: InputManager routing to BallControl)

    /// Unity: BallControl.MouseDownMethod - touch started near ball
    func aimBegan(worldPoint: SCNVector3) {
        guard gameState == .playing, ballController.ballIsStatic else { return }
        clubController.mouseDown(ballPosition: ballController.ballNode.position, worldPoint: worldPoint)
    }

    /// Unity: BallControl.MouseNormalMethod - touch moved during aim
    func aimMoved(worldPoint: SCNVector3) {
        guard gameState == .playing, ballController.ballIsStatic else { return }
        clubController.mouseNormal(ballPosition: ballController.ballNode.position, worldPoint: worldPoint)
        // Unity: UIManager.PowerBar.fillAmount = force / MaxForce
        powerBarFill = clubController.normalizedPower
    }

    /// Unity: BallControl.MouseUpMethod - touch ended, fire shot
    func aimEnded() {
        guard gameState == .playing, ballController.ballIsStatic else { return }

        if let impulse = clubController.mouseUp() {
            ballController.queueShot(impulse: impulse)
            turnManager.ballShot()
            audioManager.hitBall(power: CGFloat(clubController.normalizedPower))
        }

        powerBarFill = 0
    }

    /// Cancel aim without shooting
    func aimCancelled() {
        clubController.reset()
        powerBarFill = 0
    }

    // MARK: - Input: Camera Rotation (3rd person orbit)

    func rotateCamera(deltaX: Float, deltaY: Float) {
        guard gameState == .playing else { return }
        sceneManager.orbitCamera(deltaX: deltaX, deltaY: deltaY)
    }

    // MARK: - Game Loop (combines Unity Update + LateUpdate)

    private func startGameLoop() {
        gameLoopTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.gameLoopTick()
        }
    }

    private func stopGameLoop() {
        gameLoopTimer?.invalidate()
        gameLoopTimer = nil
    }

    private func gameLoopTick() {
        // Unity LateUpdate: camera follow
        sceneManager.updateCameraFollow()

        // Unity Update: ball state checking
        guard gameState == .playing else { return }

        // Check for fall-off (Unity: OnTriggerEnter "Destroyer")
        if ballController.hasFallenOff {
            handleBallFellOff()
            return
        }

        // Check if ball has stopped (Unity: rgBody.velocity == Vector3.zero)
        let justStopped = ballController.checkState()
        if justStopped && turnManager.ballIsMoving {
            // Ball was moving and just became static
            onBallStopped()
        }
    }

    // MARK: - Ball Fell Off Course

    private func handleBallFellOff() {
        stopGameLoop()
        audioManager.ballFellOff()

        showRestartFade = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            self?.showRestartFade = false
            self?.restartCurrentHole()
        }
    }

    // MARK: - Navigation

    func advanceToNextHole() {
        if courseManager.advanceToNextCourse() {
            startCourse()
        } else {
            gameState = .courseComplete
        }
    }

    func returnToMenu() {
        stopGameLoop()
        sceneManager.scene.isPaused = false
        sceneManager.clearCourse()
        ballController.ballNode.removeFromParentNode()
        ballController.areaAffectorNode.removeFromParentNode()
        clubController.reset()
        courseManager.resetToFirstCourse()
        scoringManager.reset()
        gameState = .mainMenu
    }

    func showLevelSelect() {
        gameState = .courseSelect
    }

    func pauseGame() {
        guard gameState == .playing else { return }
        gameState = .paused
        sceneManager.scene.isPaused = true
        stopGameLoop()
    }

    func unpauseGame() {
        guard gameState == .paused else { return }
        sceneManager.scene.isPaused = false
        startGameLoop()
        gameState = .playing
    }

    func restartCurrentHole() {
        guard let definition = courseManager.currentCourse else { return }
        stopGameLoop()
        sceneManager.scene.isPaused = false
        clubController.reset()
        powerBarFill = 0

        ballController.placeBall(at: definition.ballStart.scenePosition)
        physicsManager.setupBallPhysics(for: ballController.ballNode)
        turnManager.resetForNewHole(maxShots: definition.shotCount)

        sceneManager.setFollowTarget(ballController.ballNode)
        sceneManager.snapCameraToBall()

        gameState = .playing
        startGameLoop()
    }

    /// Retry after failure (Unity: NextRetryBtn reloads scene)
    func retryLevel() {
        restartCurrentHole()
    }

    func applySettings() {
        // Settings are applied through direct property access where needed
    }

    // MARK: - PhysicsManagerDelegate

    func physicsManager(_ manager: PhysicsManager, ballDidEnterHole ballNode: SCNNode) {
        guard gameState == .playing else { return }

        if holeDetector.shouldCaptureBall(ballNode) {
            let holePos = courseManager.currentCourse?.holePosition.scenePosition ?? SCNVector3Zero
            ballController.captureInHole(holePosition: holePos)

            // Record the shot that landed in the hole
            if turnManager.ballIsMoving {
                turnManager.shotTaken()
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.levelComplete()
            }
        }
    }

    func physicsManager(_ manager: PhysicsManager, ballDidHitFlagPole ballNode: SCNNode) {
        guard gameState == .playing else { return }

        let holePos = courseManager.currentCourse?.holePosition.scenePosition ?? SCNVector3Zero
        ballController.captureInHole(holePosition: holePos)

        if turnManager.ballIsMoving {
            turnManager.shotTaken()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.levelComplete()
        }
    }

    // MARK: - Editor (unchanged)

    func startEditor(course: CourseDefinition? = nil) {
        sceneManager.clearCourse()
        ballController.ballNode.removeFromParentNode()
        ballController.areaAffectorNode.removeFromParentNode()
        clubController.reset()

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
