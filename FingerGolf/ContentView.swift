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

            // Layer 2: HUD (visible during play + pause)
            if coordinator.gameState == .playing || coordinator.gameState == .paused {
                GameHUDView(
                    turnManager: coordinator.turnManager,
                    scoringManager: coordinator.scoringManager,
                    currentPar: coordinator.currentPar,
                    powerBarFill: coordinator.powerBarFill,
                    onNextHole: { coordinator.advanceToNextHole() },
                    onReturnToMenu: { coordinator.returnToMenu() },
                    onPause: { coordinator.pauseGame() },
                    onRestart: { coordinator.restartCurrentHole() }
                )
                .allowsHitTesting(coordinator.gameState == .playing)
            }

            // Layer 3: Modal overlays based on game state
            modalOverlay

            // Layer 3.5: Restart fade effect (ball fell off)
            if coordinator.showRestartFade {
                RestartFadeEffect(
                    centerPosition: ballScreenPosition,
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

    /// Project ball position to screen for fade effect center
    private var ballScreenPosition: CGPoint {
        guard let scnView else { return CGPoint(x: UIScreen.main.bounds.midX, y: UIScreen.main.bounds.midY) }
        let projected = scnView.projectPoint(coordinator.ballController.ballNode.position)
        return CGPoint(x: CGFloat(projected.x), y: CGFloat(projected.y))
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

        case .failed:
            // Unity: GameManager.GameStatus.Failed -> LevelManager shows retry panel
            failedOverlay

        case .holeComplete:
            holeCompleteOverlay

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

    // MARK: - Failed Overlay (Unity: NextRetryBtn panel)

    private var failedOverlay: some View {
        VStack(spacing: 16) {
            Text("OUT OF SHOTS!")
                .headingStyle(size: 28)

            Text("You used all \(coordinator.turnManager.maxShots) shots")
                .lightStyle(size: 16)

            HStack(spacing: 16) {
                Button("MENU") {
                    coordinator.returnToMenu()
                }
                .bodyStyle(size: 15)
                .buttonStyle(.bordered)

                Button("RETRY") {
                    coordinator.retryLevel()
                }
                .bodyStyle(size: 15)
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            }
        }
        .padding(30)
        .background(.ultraThickMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Hole Complete Overlay

    private var holeCompleteOverlay: some View {
        VStack(spacing: 16) {
            Text("HOLE COMPLETE!")
                .headingStyle(size: 28)

            let diff = coordinator.turnManager.strokeCount - coordinator.currentPar
            let label = scoreLabel(for: diff, strokes: coordinator.turnManager.strokeCount)

            Text(label.uppercased())
                .headingStyle(size: 22)
                .foregroundStyle(diff <= 0 ? .green : .orange)

            Text("\(coordinator.turnManager.strokeCount) STROKE\(coordinator.turnManager.strokeCount == 1 ? "" : "S")")
                .lightStyle(size: 16)

            HStack(spacing: 16) {
                Button("MENU") {
                    coordinator.returnToMenu()
                }
                .bodyStyle(size: 15)
                .buttonStyle(.bordered)

                Button("NEXT HOLE") {
                    coordinator.advanceToNextHole()
                }
                .bodyStyle(size: 15)
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
        }
        .padding(30)
        .background(.ultraThickMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Course Complete Overlay

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

    // MARK: - Helpers

    private func scoreLabel(for relativeToPar: Int, strokes: Int) -> String {
        if strokes == 1 {
            return "Hole in One!"
        }
        switch relativeToPar {
        case ..<(-2): return "Albatross!"
        case -2: return "Eagle!"
        case -1: return "Birdie!"
        case 0: return "Par"
        case 1: return "Bogey"
        case 2: return "Double Bogey"
        default: return "+\(relativeToPar)"
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
