import SwiftUI

struct GameHUDView: View {

    @ObservedObject var turnManager: TurnManager
    @ObservedObject var scoringManager: ScoringManager
    let currentPar: Int

    var onNextHole: () -> Void
    var onReturnToMenu: () -> Void

    var body: some View {
        VStack {
            // Top bar
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Hole \(scoringManager.currentHole)")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                    Text("Par \(currentPar)")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("Strokes: \(turnManager.strokeCount)")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                    if turnManager.strokeCount > 0 {
                        let diff = turnManager.strokeCount - currentPar
                        Text(diff == 0 ? "Even" : (diff > 0 ? "+\(diff)" : "\(diff)"))
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(diff <= 0 ? .green : .red)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 16)
            .padding(.top, 8)

            Spacer()

            // State instruction
            stateInstruction
                .padding(.bottom, 30)

            // Hole complete overlay
            if turnManager.state == .holeComplete {
                holeCompleteOverlay
            }
        }
        .allowsHitTesting(turnManager.state == .holeComplete)
    }

    @ViewBuilder
    private var stateInstruction: some View {
        switch turnManager.state {
        case .placingClub:
            instructionBadge("Tap to place your club")
        case .readyToSwing:
            instructionBadge("Flick fingers to swing!")
        case .swinging:
            EmptyView()
        case .ballMoving:
            instructionBadge("Ball in play...")
        case .holeComplete:
            EmptyView()
        default:
            EmptyView()
        }
    }

    private func instructionBadge(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 15, weight: .medium, design: .rounded))
            .foregroundStyle(.primary)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
    }

    private var holeCompleteOverlay: some View {
        VStack(spacing: 16) {
            Text("Hole Complete!")
                .font(.system(size: 28, weight: .bold, design: .rounded))

            let diff = turnManager.strokeCount - currentPar
            let label = scoreLabel(for: diff)

            Text(label)
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundStyle(diff <= 0 ? .green : .orange)

            Text("\(turnManager.strokeCount) stroke\(turnManager.strokeCount == 1 ? "" : "s")")
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                Button("Menu") {
                    onReturnToMenu()
                }
                .buttonStyle(.bordered)

                Button("Next Hole") {
                    onNextHole()
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
        }
        .padding(30)
        .background(.ultraThickMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func scoreLabel(for relativeToPar: Int) -> String {
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
