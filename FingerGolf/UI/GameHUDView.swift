import SwiftUI

struct GameHUDView: View {

    @ObservedObject var turnManager: TurnManager
    @ObservedObject var scoringManager: ScoringManager
    let currentPar: Int

    var onNextHole: () -> Void
    var onReturnToMenu: () -> Void
    var onPause: () -> Void
    var onRestart: () -> Void

    var body: some View {
        ZStack {
            // Layer 1: Score display + instructions (non-interactive, at bottom)
            VStack {
                Spacer()

                stateInstruction

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("HOLE \(scoringManager.currentHole)")
                            .bodyStyle(size: 18)
                        Text("PAR \(currentPar)")
                            .lightStyle(size: 13)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("STROKES: \(turnManager.strokeCount)")
                            .bodyStyle(size: 18)
                        if turnManager.strokeCount > 0 {
                            let diff = turnManager.strokeCount - currentPar
                            Text(diff == 0 ? "EVEN" : (diff > 0 ? "+\(diff)" : "\(diff)"))
                                .font(.custom("Futura-Bold", size: 13))
                                .foregroundStyle(diff <= 0 ? .green : .red)
                                .shadow(color: .black.opacity(0.5), radius: 1, x: 0.5, y: 1)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            .allowsHitTesting(false)

            // Layer 2: Pause + Restart buttons (in left dynamic island gap)
            VStack {
                HStack(spacing: 6) {
                    Button(action: onRestart) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.5), radius: 1, x: 0.5, y: 1)
                            .frame(width: 28, height: 28)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    Button(action: onPause) {
                        Image(systemName: "pause.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.5), radius: 1, x: 0.5, y: 1)
                            .frame(width: 28, height: 28)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    Spacer()
                }
                .padding(.leading, 14)
                .padding(.top, 14)
                Spacer()
            }
            .ignoresSafeArea(edges: .top)

            // Layer 3: Hole complete overlay
            if turnManager.state == .holeComplete {
                holeCompleteOverlay
            }
        }
    }

    @ViewBuilder
    private var stateInstruction: some View {
        switch turnManager.state {
        case .placingClub:
            instructionBadge("Tap the ball and drag to aim")
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
            .bodyStyle(size: 14)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
    }

    private var holeCompleteOverlay: some View {
        VStack(spacing: 16) {
            Text("HOLE COMPLETE!")
                .headingStyle(size: 28)

            let diff = turnManager.strokeCount - currentPar
            let label = scoreLabel(for: diff)

            Text(label.uppercased())
                .headingStyle(size: 22)
                .foregroundStyle(diff <= 0 ? .green : .orange)

            HStack(spacing: 4) {
                ForEach(0..<min(turnManager.strokeCount, 5), id: \.self) { _ in
                    Image("GameUI/star")
                        .resizable()
                        .frame(width: 20, height: 20)
                }
            }

            Text("\(turnManager.strokeCount) STROKE\(turnManager.strokeCount == 1 ? "" : "S")")
                .lightStyle(size: 16)

            HStack(spacing: 16) {
                Button("MENU") {
                    onReturnToMenu()
                }
                .bodyStyle(size: 15)
                .buttonStyle(.bordered)

                Button("NEXT HOLE") {
                    onNextHole()
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

    private func scoreLabel(for relativeToPar: Int) -> String {
        if turnManager.strokeCount == 1 {
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
