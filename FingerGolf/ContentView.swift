import SwiftUI
import SceneKit

struct ContentView: View {

    @StateObject private var coordinator = GameCoordinator()
    @State private var showingSettings = false
    @State private var scnView: SCNView?

    var body: some View {
        ZStack {
            // Layer 1: 3D game scene (always present)
            GameSceneView(coordinator: coordinator, scnViewBinding: $scnView)
                .ignoresSafeArea()

            // Layer 1.5: Trajectory preview overlay (UI-based, above 3D scene)
            if coordinator.gameState == .playing,
               coordinator.turnManager.state == .placingClub,
               let direction = coordinator.clubController.aimDirection {
                TrajectoryOverlay(
                    scnView: scnView,
                    ballPosition: coordinator.ballController.ballNode.position,
                    direction: direction,
                    power: coordinator.trajectoryPower,
                    isVisible: true
                )
                .ignoresSafeArea()
            }

            // Layer 2: HUD (visible during play + pause)
            if coordinator.gameState == .playing || coordinator.gameState == .paused {
                GameHUDView(
                    turnManager: coordinator.turnManager,
                    scoringManager: coordinator.scoringManager,
                    currentPar: coordinator.currentPar,
                    onNextHole: { coordinator.advanceToNextHole() },
                    onReturnToMenu: { coordinator.returnToMenu() },
                    onPause: { coordinator.pauseGame() },
                    onRestart: { coordinator.restartCurrentHole() }
                )
                .allowsHitTesting(coordinator.gameState == .playing)
            }

            // Layer 3: Modal overlays based on game state
            modalOverlay

            // Layer 3.5: Restart fade effect
            if coordinator.showRestartFade {
                RestartFadeEffect(
                    centerPosition: coordinator.holeScreenPosition,
                    onComplete: {}
                )
                .ignoresSafeArea()
            }

            // Layer 4: Settings (on top of everything)
            if showingSettings {
                SettingsView(
                    settings: coordinator.settings,
                    onDone: {
                        showingSettings = false
                        coordinator.applySettings()
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(red: 0.1, green: 0.15, blue: 0.1, opacity: 0.95).ignoresSafeArea())
            }
        }
    }

    // MARK: - Modal Overlays

    @ViewBuilder
    private var modalOverlay: some View {
        switch coordinator.gameState {
        case .mainMenu:
            ZStack {
                OceanBackgroundWrapper()
                    .ignoresSafeArea()
                MainMenuView(
                    onStartPressed: { coordinator.showLevelSelect() },
                    onBuildPressed: { coordinator.startEditor() },
                    onFindCoursePressed: { coordinator.showFindCourse() },
                    onSettingsPressed: { showingSettings = true }
                )
            }

        case .courseSelect:
            LevelSelectView(
                courses: coordinator.courseManager.courses,
                progressManager: coordinator.progressManager,
                onSelectLevel: { index in coordinator.startCourse(at: index) },
                onBack: { coordinator.returnToMenu() }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.opacity(0.6).ignoresSafeArea())

        case .paused:
            PauseMenuView(
                onResume: { coordinator.unpauseGame() },
                onRestart: { coordinator.restartCurrentHole() },
                onSettings: { showingSettings = true },
                onQuit: { coordinator.returnToMenu() }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.opacity(0.5).ignoresSafeArea())

        case .courseComplete:
            courseCompleteOverlay

        case .editing:
            LevelEditorView(
                editorController: coordinator.editorController,
                onSave: { _ = coordinator.saveEditorCourse() },
                onTest: { coordinator.testEditorCourse() },
                onPublish: {
                    if let userCourse = coordinator.saveEditorCourse() {
                        Task { try? await coordinator.cloudKitManager.publishCourse(userCourse) }
                    }
                },
                onBack: { coordinator.exitEditor() }
            )

        case .findCourse:
            FindCourseView(
                cloudKitManager: coordinator.cloudKitManager,
                onSelectCourse: { userCourse in coordinator.playCommunityLevel(userCourse) },
                onBack: { coordinator.returnToMenu() }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(red: 0.05, green: 0.1, blue: 0.15, opacity: 0.95).ignoresSafeArea())

        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private var courseCompleteOverlay: some View {
        if coordinator.currentCommunityRecordID != nil {
            LeaderboardView(
                cloudKitManager: coordinator.cloudKitManager,
                courseName: coordinator.courseManager.currentCourse?.name ?? "Course",
                playerStrokes: coordinator.turnManager.strokeCount,
                par: coordinator.courseManager.currentCourse?.par ?? 3,
                onDone: { coordinator.returnToMenu() }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.opacity(0.6).ignoresSafeArea())
            .task {
                guard let recordID = coordinator.currentCommunityRecordID else { return }
                await coordinator.cloudKitManager.fetchLeaderboard(courseRecordName: recordID)
                let playerName = await coordinator.cloudKitManager.fetchPlayerName()
                try? await coordinator.cloudKitManager.submitScore(
                    courseRecordName: recordID,
                    strokes: coordinator.turnManager.strokeCount,
                    playerName: playerName
                )
                await coordinator.cloudKitManager.fetchLeaderboard(courseRecordName: recordID)
            }
        } else {
            ScoreCardView(
                scores: coordinator.scoringManager.scores,
                totalStrokes: coordinator.scoringManager.totalStrokes,
                totalPar: coordinator.scoringManager.totalPar,
                onReturnToMenu: { coordinator.returnToMenu() }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.opacity(0.4).ignoresSafeArea())
        }
    }
}

// MARK: - Ocean Background Wrapper

struct OceanBackgroundWrapper: UIViewRepresentable {
    func makeUIView(context: Context) -> OceanBackground {
        let ocean = OceanBackground(frame: .zero)
        ocean.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        ocean.startAnimating()
        return ocean
    }

    func updateUIView(_ uiView: OceanBackground, context: Context) {}
}
