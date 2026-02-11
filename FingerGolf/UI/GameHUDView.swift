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
                    Text("HOLE \(scoringManager.currentHole)")
                        .font(.custom("Noteworthy-Bold", size: 18))
                    Text("PAR \(currentPar)")
                        .font(.custom("Noteworthy-Light", size: 13))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("STROKES: \(turnManager.strokeCount)")
                        .font(.custom("Noteworthy-Bold", size: 18))
                    if turnManager.strokeCount > 0 {
                        let diff = turnManager.strokeCount - currentPar
                        Text(diff == 0 ? "EVEN" : (diff > 0 ? "+\(diff)" : "\(diff)"))
                            .font(.custom("Noteworthy-Bold", size: 13))
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
        Text(text.uppercased())
            .font(.custom("Noteworthy-Bold", size: 14))
            .foregroundStyle(.primary)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
    }

    private var holeCompleteOverlay: some View {
        VStack(spacing: 16) {
            Text("HOLE COMPLETE!")
                .font(.custom("Noteworthy-Bold", size: 28))

            let diff = turnManager.strokeCount - currentPar
            let label = scoreLabel(for: diff)

            Text(label.uppercased())
                .font(.custom("Noteworthy-Bold", size: 22))
                .foregroundStyle(diff <= 0 ? .green : .orange)

            HStack(spacing: 4) {
                ForEach(0..<min(turnManager.strokeCount, 5), id: \.self) { _ in
                    Image("GameUI/star")
                        .resizable()
                        .frame(width: 20, height: 20)
                }
            }

            Text("\(turnManager.strokeCount) STROKE\(turnManager.strokeCount == 1 ? "" : "S")")
                .font(.custom("Noteworthy-Light", size: 16))
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                Button("MENU") {
                    onReturnToMenu()
                }
                .font(.custom("Noteworthy-Bold", size: 15))
                .buttonStyle(.bordered)

                Button("NEXT HOLE") {
                    onNextHole()
                }
                .font(.custom("Noteworthy-Bold", size: 15))
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
