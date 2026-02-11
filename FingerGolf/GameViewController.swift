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
        // Pan gesture for club aim and camera rotation
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        scnView.addGestureRecognizer(panGesture)

        // Tap gesture for club placement
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        scnView.addGestureRecognizer(tapGesture)
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
            } else if gameCoordinator.gameState == .playing {
                // Camera rotation when not aiming
                let translation = gesture.translation(in: scnView)
                let rotationSpeed: Float = 0.005
                gameCoordinator.sceneManager.rotateCameraOrbit(by: Float(translation.x) * rotationSpeed)
                gesture.setTranslation(.zero, in: scnView)
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
            courses: gameCoordinator.courseManager.courses,
            onStartCourse: { [weak self] index in
                self?.dismissMenu()
                self?.gameCoordinator.startCourse(at: index)
                self?.refreshHUD()
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
                case .playing:
                    self.refreshHUD()
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
