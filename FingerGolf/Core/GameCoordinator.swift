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

    private(set) var physicsManager: PhysicsManager!
    private(set) var holeDetector: HoleDetector!
    let editorController = EditorController()
    lazy var cloudKitManager = CloudKitManager.shared
    let audioManager = AudioManager.shared

    // MARK: - State

    @Published var gameState: GameState = .mainMenu
    @Published var showRestartFade: Bool = false
    @Published var powerBarFill: Float = 0.0

    private var gameLoopTimer: Timer?

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

        // Setup physics for each piece - uses the actual mesh as collision surface
        for child in courseNode.childNodes {
            physicsManager.setupCoursePiecePhysics(for: child)
        }

        // Add hole trigger
        let holeTrigger = physicsManager.setupHoleTrigger(at: definition.holePosition.scenePosition)
        courseNode.addChildNode(holeTrigger)
        holeDetector.setHolePosition(definition.holePosition.scenePosition)

        // Setup flag physics
        if let flagNode = courseNode.childNode(withName: "flag", recursively: true) {
            physicsManager.setupFlagPhysics(for: flagNode)
        }

        // Set course in scene
        sceneManager.setCourseRoot(courseNode)

        // Place ball at start
        ballController.ballNode.removeFromParentNode()
        ballController.areaAffectorNode.removeFromParentNode()
        ballController.cancelAim()

        physicsManager.setupBallPhysics(for: ballController.ballNode)
        ballController.placeBall(at: definition.ballStart.scenePosition)
        sceneManager.scene.rootNode.addChildNode(ballController.ballNode)
        sceneManager.scene.rootNode.addChildNode(ballController.areaAffectorNode)

        // Camera setup
        sceneManager.enablePerspectiveCamera()
        sceneManager.setFollowTarget(ballController.ballNode)
        sceneManager.snapCameraToBall()

        // Add trajectory dots to scene
        ballController.addToScene(sceneManager.scene.rootNode)

        // Reset turn manager
        turnManager.resetForNewHole(maxShots: definition.shotCount)

        gameState = .playing
        powerBarFill = 0

        startGameLoop()
    }

    // MARK: - Level Complete

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

    // MARK: - Level Failed

    func levelFailed() {
        guard gameState == .playing else { return }
        stopGameLoop()
        audioManager.ballFellOff()
        gameState = .failed
    }

    // MARK: - Shot Handling

    private func onBallStopped() {
        let shotsRemain = turnManager.shotTaken()

        if holeDetector.shouldCaptureBall(ballController.ballNode) {
            let holePos = courseManager.currentCourse?.holePosition.scenePosition ?? SCNVector3Zero
            ballController.captureInHole(holePosition: holePos)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.levelComplete()
            }
            return
        }

        if !shotsRemain {
            levelFailed()
        }
    }

    // MARK: - Input: Aiming

    func aimBegan(worldPoint: SCNVector3) {
        guard gameState == .playing, ballController.ballIsStatic else { return }
        ballController.aimBegan(worldPoint: worldPoint)
    }

    func aimMoved(worldPoint: SCNVector3) {
        guard gameState == .playing, ballController.ballIsStatic else { return }
        ballController.aimMoved(worldPoint: worldPoint)
        powerBarFill = ballController.normalizedPower
    }

    func aimEnded() {
        guard gameState == .playing, ballController.ballIsStatic else { return }

        if let impulse = ballController.aimEnded() {
            ballController.queueShot(impulse: impulse)
            turnManager.ballShot()
            audioManager.hitBall(power: CGFloat(ballController.normalizedPower))
        }

        powerBarFill = 0
    }

    func aimCancelled() {
        ballController.cancelAim()
        powerBarFill = 0
    }

    // MARK: - Input: Camera Rotation

    func rotateCamera(deltaX: Float, deltaY: Float) {
        guard gameState == .playing else { return }
        sceneManager.orbitCamera(deltaX: deltaX, deltaY: deltaY)
    }

    func zoomCamera(scale: Float) {
        guard gameState == .playing else { return }
        sceneManager.zoomCamera(by: scale)
    }

    // MARK: - Game Loop

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
        sceneManager.updateCameraFollow()

        guard gameState == .playing else { return }

        if ballController.hasFallenOff {
            handleBallFellOff()
            return
        }

        let justStopped = ballController.checkState()
        if justStopped && turnManager.ballIsMoving {
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
        ballController.cancelAim()
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
        ballController.cancelAim()
        powerBarFill = 0

        physicsManager.setupBallPhysics(for: ballController.ballNode)
        ballController.placeBall(at: definition.ballStart.scenePosition)
        turnManager.resetForNewHole(maxShots: definition.shotCount)

        sceneManager.setFollowTarget(ballController.ballNode)
        sceneManager.snapCameraToBall()

        gameState = .playing
        startGameLoop()
    }

    func retryLevel() {
        restartCurrentHole()
    }

    func applySettings() {}

    // MARK: - PhysicsManagerDelegate

    func physicsManager(_ manager: PhysicsManager, ballDidEnterHole ballNode: SCNNode) {
        guard gameState == .playing else { return }

        if holeDetector.shouldCaptureBall(ballNode) {
            let holePos = courseManager.currentCourse?.holePosition.scenePosition ?? SCNVector3Zero
            ballController.captureInHole(holePosition: holePos)

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

    // MARK: - Editor

    func startEditor(course: CourseDefinition? = nil) {
        sceneManager.clearCourse()
        ballController.ballNode.removeFromParentNode()
        ballController.areaAffectorNode.removeFromParentNode()
        ballController.cancelAim()

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
