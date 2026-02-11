import UIKit
import QuartzCore
import SceneKit
import Combine
import SwiftUI

class GameViewController: UIViewController, SCNSceneRendererDelegate {

    // MARK: - Properties

    private var scnView: SCNView!
    private let gameCoordinator = GameCoordinator()
    private var cancellables = Set<AnyCancellable>()

    // Touch tracking for club placement and aim
    private var touchStartPosition: SCNVector3?
    private var isDragging = false

    // Hand tracking overlay
    private var fingerDotsOverlay: FingerDotsOverlay!

    // UI overlays
    private var hudHostingController: UIHostingController<GameHUDView>?
    private var menuHostingController: UIHostingController<MainMenuView>?
    private var scoreCardHostingController: UIHostingController<ScoreCardView>?
    private var permissionHostingController: UIHostingController<PermissionView>?
    private var levelSelectHostingController: UIHostingController<LevelSelectView>?
    private var pauseHostingController: UIHostingController<PauseMenuView>?
    private var settingsHostingController: UIHostingController<SettingsView>?

    // Pinch zoom
    private let minOrthoScale: Double = 1.5
    private let maxOrthoScale: Double = 8.0

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        scnView = self.view as? SCNView
        scnView.scene = gameCoordinator.sceneManager.scene
        scnView.delegate = self
        scnView.allowsCameraControl = false
        scnView.showsStatistics = false
        scnView.backgroundColor = .clear
        scnView.antialiasingMode = .multisampling4X
        scnView.isPlaying = true

        setupGestures()
        setupFingerDotsOverlay()
        setupHUD()
        observeGameState()
        observePermission()

        // Request camera permission immediately on launch
        gameCoordinator.startHandTracking()

        // Start with menu
        showMainMenu()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        gameCoordinator.handTrackingCoordinator.setViewSize(view.bounds.size)
    }

    // MARK: - Finger Dots Overlay

    private func setupFingerDotsOverlay() {
        fingerDotsOverlay = FingerDotsOverlay(frame: view.bounds)
        fingerDotsOverlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(fingerDotsOverlay)
        fingerDotsOverlay.bind(to: gameCoordinator.handTrackingCoordinator)
    }

    // MARK: - Gesture Setup

    private func setupGestures() {
        // Pan gesture for club aim
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        scnView.addGestureRecognizer(panGesture)

        // Tap gesture for club placement
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        scnView.addGestureRecognizer(tapGesture)

        // Swipe gestures for camera rotation between 4 isometric angles
        let swipeLeft = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
        swipeLeft.direction = .left
        scnView.addGestureRecognizer(swipeLeft)

        let swipeRight = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
        swipeRight.direction = .right
        scnView.addGestureRecognizer(swipeRight)

        // Pinch gesture for zoom
        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        scnView.addGestureRecognizer(pinchGesture)

        // Let pan and swipe coexist
        panGesture.require(toFail: swipeLeft)
        panGesture.require(toFail: swipeRight)
    }

    // MARK: - Touch Handling

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        guard gameCoordinator.gameState == .playing else { return }
        guard gameCoordinator.turnManager.state == .placingClub else { return }

        let location = gesture.location(in: scnView)
        guard let worldPosition = hitTestCoursePosition(at: location) else { return }

        gameCoordinator.handleClubPlacement(at: worldPosition)
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let location = gesture.location(in: scnView)

        switch gesture.state {
        case .began:
            if gameCoordinator.gameState == .playing &&
               gameCoordinator.turnManager.state == .readyToSwing {
                // Dragging to aim
                isDragging = true
                touchStartPosition = hitTestCoursePosition(at: location)
            }

        case .changed:
            if isDragging {
                // Update aim direction
                if let worldPosition = hitTestCoursePosition(at: location) {
                    gameCoordinator.handleAimUpdate(toward: worldPosition)
                }
            }

        case .ended, .cancelled:
            if isDragging {
                // Calculate power from drag distance
                let translation = gesture.translation(in: scnView)
                let dragDistance = sqrt(translation.x * translation.x + translation.y * translation.y)
                let power = min(dragDistance / 200.0, 1.0)

                if power > 0.02 {
                    gameCoordinator.handleSwing(power: power)
                }
                isDragging = false
                touchStartPosition = nil
            }

        default:
            break
        }
    }

    @objc private func handleSwipe(_ gesture: UISwipeGestureRecognizer) {
        guard gameCoordinator.gameState == .playing else { return }

        if gesture.direction == .left {
            gameCoordinator.sceneManager.rotateToNextAngle()
        } else if gesture.direction == .right {
            gameCoordinator.sceneManager.rotateToPreviousAngle()
        }
    }

    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        guard gameCoordinator.gameState == .playing else { return }
        guard let camera = gameCoordinator.sceneManager.cameraNode.camera else { return }

        if gesture.state == .changed {
            // Pinch out (scale > 1) = zoom in = smaller ortho scale
            let newScale = camera.orthographicScale / Double(gesture.scale)
            camera.orthographicScale = min(max(newScale, minOrthoScale), maxOrthoScale)
            gesture.scale = 1.0
        }
    }

    // MARK: - Hit Testing

    private func hitTestCoursePosition(at screenPoint: CGPoint) -> SCNVector3? {
        let hitResults = scnView.hitTest(screenPoint, options: [
            .searchMode: SCNHitTestSearchMode.closest.rawValue
        ])

        if let hit = hitResults.first {
            return hit.worldCoordinates
        }

        // Fallback: project onto Y=0 plane
        let projectedPoints = scnView.hitTest(screenPoint, options: [
            .searchMode: SCNHitTestSearchMode.all.rawValue
        ])
        if let hit = projectedPoints.first {
            return SCNVector3(hit.worldCoordinates.x, 0.065, hit.worldCoordinates.z)
        }

        return nil
    }

    // MARK: - SCNSceneRendererDelegate

    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        // Game coordinator handles ball state checking via its own timer
    }

    // MARK: - HUD

    private func setupHUD() {
        let hudView = GameHUDView(
            turnManager: gameCoordinator.turnManager,
            scoringManager: gameCoordinator.scoringManager,
            currentPar: gameCoordinator.currentPar,
            onNextHole: { [weak self] in self?.gameCoordinator.advanceToNextHole() },
            onReturnToMenu: { [weak self] in
                self?.gameCoordinator.returnToMenu()
            },
            onPause: { [weak self] in
                self?.gameCoordinator.pauseGame()
            }
        )
        let hc = UIHostingController(rootView: hudView)
        hc.view.backgroundColor = .clear
        hc.view.isUserInteractionEnabled = true
        addChild(hc)
        view.addSubview(hc.view)
        hc.view.frame = view.bounds
        hc.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        hc.didMove(toParent: self)
        hudHostingController = hc
    }

    private func refreshHUD() {
        hudHostingController?.willMove(toParent: nil)
        hudHostingController?.view.removeFromSuperview()
        hudHostingController?.removeFromParent()
        hudHostingController = nil
        setupHUD()
        // Re-add finger dots on top of HUD
        view.bringSubviewToFront(fingerDotsOverlay)
    }

    // MARK: - Main Menu

    private func showMainMenu() {
        dismissAllOverlays()

        let menuView = MainMenuView(
            onStartPressed: { [weak self] in
                self?.gameCoordinator.showLevelSelect()
            },
            onSettingsPressed: { [weak self] in
                self?.showSettings(returnTo: .mainMenu)
            }
        )
        let mc = UIHostingController(rootView: menuView)
        mc.view.backgroundColor = .clear

        // Add animated ocean background behind menu
        let oceanBg = OceanBackground(frame: view.bounds)
        oceanBg.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        oceanBg.tag = 999
        mc.view.insertSubview(oceanBg, at: 0)
        oceanBg.startAnimating()

        addChild(mc)
        view.addSubview(mc.view)
        mc.view.frame = view.bounds
        mc.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        mc.didMove(toParent: self)
        menuHostingController = mc
    }

    private func dismissMenu() {
        menuHostingController?.willMove(toParent: nil)
        menuHostingController?.view.removeFromSuperview()
        menuHostingController?.removeFromParent()
        menuHostingController = nil
    }

    // MARK: - Level Select

    private func showLevelSelect() {
        dismissLevelSelect()

        let levelView = LevelSelectView(
            courses: gameCoordinator.courseManager.courses,
            progressManager: gameCoordinator.progressManager,
            onSelectLevel: { [weak self] index in
                self?.dismissMenu()
                self?.dismissLevelSelect()
                self?.gameCoordinator.startCourse(at: index)
                self?.refreshHUD()
            },
            onBack: { [weak self] in
                self?.dismissLevelSelect()
                self?.gameCoordinator.returnToMenu()
            }
        )
        let lc = UIHostingController(rootView: levelView)
        lc.view.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        addChild(lc)
        view.addSubview(lc.view)
        lc.view.frame = view.bounds
        lc.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        lc.didMove(toParent: self)
        levelSelectHostingController = lc
    }

    private func dismissLevelSelect() {
        levelSelectHostingController?.willMove(toParent: nil)
        levelSelectHostingController?.view.removeFromSuperview()
        levelSelectHostingController?.removeFromParent()
        levelSelectHostingController = nil
    }

    // MARK: - Pause Menu

    private func showPauseMenu() {
        dismissPauseMenu()

        let pauseView = PauseMenuView(
            onResume: { [weak self] in
                self?.gameCoordinator.unpauseGame()
            },
            onRestart: { [weak self] in
                self?.dismissPauseMenu()
                self?.gameCoordinator.restartCurrentHole()
                self?.refreshHUD()
            },
            onSettings: { [weak self] in
                self?.showSettings(returnTo: .paused)
            },
            onQuit: { [weak self] in
                self?.dismissPauseMenu()
                self?.gameCoordinator.returnToMenu()
            }
        )
        let pc = UIHostingController(rootView: pauseView)
        pc.view.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        addChild(pc)
        view.addSubview(pc.view)
        pc.view.frame = view.bounds
        pc.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        pc.didMove(toParent: self)
        pauseHostingController = pc
    }

    private func dismissPauseMenu() {
        pauseHostingController?.willMove(toParent: nil)
        pauseHostingController?.view.removeFromSuperview()
        pauseHostingController?.removeFromParent()
        pauseHostingController = nil
    }

    // MARK: - Settings

    private func showSettings(returnTo: GameState) {
        dismissSettings()

        let settingsView = SettingsView(
            settings: gameCoordinator.settings,
            onDone: { [weak self] in
                self?.dismissSettings()
                self?.gameCoordinator.applySettings()
                switch returnTo {
                case .mainMenu:
                    break // Menu is still showing behind
                case .paused:
                    break // Pause menu is still showing behind
                default:
                    break
                }
            }
        )
        let sc = UIHostingController(rootView: settingsView)
        sc.view.backgroundColor = UIColor(red: 0.1, green: 0.15, blue: 0.1, alpha: 0.95)
        addChild(sc)
        view.addSubview(sc.view)
        sc.view.frame = view.bounds
        sc.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        sc.didMove(toParent: self)
        settingsHostingController = sc
    }

    private func dismissSettings() {
        settingsHostingController?.willMove(toParent: nil)
        settingsHostingController?.view.removeFromSuperview()
        settingsHostingController?.removeFromParent()
        settingsHostingController = nil
    }

    // MARK: - Score Card

    private func showScoreCard() {
        let scoreView = ScoreCardView(
            scores: gameCoordinator.scoringManager.scores,
            totalStrokes: gameCoordinator.scoringManager.totalStrokes,
            totalPar: gameCoordinator.scoringManager.totalPar,
            onReturnToMenu: { [weak self] in
                self?.dismissScoreCard()
                self?.gameCoordinator.returnToMenu()
            }
        )
        let sc = UIHostingController(rootView: scoreView)
        sc.view.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        addChild(sc)
        view.addSubview(sc.view)
        sc.view.frame = view.bounds
        sc.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        sc.didMove(toParent: self)
        scoreCardHostingController = sc
    }

    private func dismissScoreCard() {
        scoreCardHostingController?.willMove(toParent: nil)
        scoreCardHostingController?.view.removeFromSuperview()
        scoreCardHostingController?.removeFromParent()
        scoreCardHostingController = nil
    }

    // MARK: - Permission View

    private func showPermissionView() {
        guard permissionHostingController == nil else { return }

        let permView = PermissionView(
            onContinueWithoutCamera: { [weak self] in
                self?.dismissPermissionView()
            }
        )
        let pc = UIHostingController(rootView: permView)
        pc.view.backgroundColor = UIColor(red: 0.55, green: 0.78, blue: 0.9, alpha: 1.0)
        addChild(pc)
        view.addSubview(pc.view)
        pc.view.frame = view.bounds
        pc.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        pc.didMove(toParent: self)
        permissionHostingController = pc
    }

    private func dismissPermissionView() {
        permissionHostingController?.willMove(toParent: nil)
        permissionHostingController?.view.removeFromSuperview()
        permissionHostingController?.removeFromParent()
        permissionHostingController = nil
    }

    // MARK: - Helpers

    private func dismissAllOverlays() {
        dismissMenu()
        dismissLevelSelect()
        dismissPauseMenu()
        dismissSettings()
        dismissScoreCard()
        dismissPermissionView()
    }

    // MARK: - Game State Observation

    private func observeGameState() {
        gameCoordinator.$gameState
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                guard let self else { return }
                switch state {
                case .mainMenu:
                    self.showMainMenu()
                case .courseSelect:
                    self.showLevelSelect()
                case .playing:
                    self.dismissPauseMenu()
                    self.dismissLevelSelect()
                    self.refreshHUD()
                case .paused:
                    self.showPauseMenu()
                case .courseComplete:
                    self.showScoreCard()
                default:
                    break
                }
            }
            .store(in: &cancellables)
    }

    private func observePermission() {
        gameCoordinator.$cameraPermissionDenied
            .receive(on: RunLoop.main)
            .sink { [weak self] denied in
                if denied {
                    self?.showPermissionView()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Interface

    override var prefersStatusBarHidden: Bool { true }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .portrait }
}
