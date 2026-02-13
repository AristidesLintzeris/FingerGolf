import SwiftUI

struct GameHUDView: View {

    @ObservedObject var turnManager: TurnManager
    @ObservedObject var scoringManager: ScoringManager
    let currentPar: Int
    let powerBarFill: Float  // Unity: UIManager.PowerBar.fillAmount (0-1)

    var onNextHole: () -> Void
    var onReturnToMenu: () -> Void
    var onPause: () -> Void
    var onRestart: () -> Void

    var body: some View {
        ZStack {
            // Layer 1: Power bar + Score display (non-interactive, at bottom)
            VStack(spacing: 8) {
                Spacer()

                // Unity: UIManager.PowerBar
                if powerBarFill > 0 {
                    powerBar
                        .padding(.horizontal, 40)
                }

                stateInstruction

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("HOLE \(scoringManager.currentHole)")
                            .bodyStyle(size: 18)
                        Text("PAR \(currentPar)")
                            .lightStyle(size: 13)
                    }

                    Spacer()

                    // Unity: UIManager.shotText
                    VStack(alignment: .center, spacing: 2) {
                        Text("\(turnManager.shotCount)")
                            .font(.custom("Futura-Bold", size: 28))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.5), radius: 1, x: 0.5, y: 1)
                        Text("SHOTS LEFT")
                            .lightStyle(size: 11)
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
        }
    }

    // MARK: - Power Bar (Unity: UIManager.PowerBar)

    private var powerBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.black.opacity(0.4))

                // Fill
                RoundedRectangle(cornerRadius: 6)
                    .fill(powerBarColor)
                    .frame(width: geo.size.width * CGFloat(powerBarFill))
            }
        }
        .frame(height: 12)
    }

    private var powerBarColor: Color {
        if powerBarFill < 0.33 {
            return .green
        } else if powerBarFill < 0.66 {
            return .yellow
        } else {
            return .red
        }
    }

    // MARK: - State Instruction

    @ViewBuilder
    private var stateInstruction: some View {
        if turnManager.ballIsMoving {
            instructionBadge("Ball in play...")
        } else if turnManager.shotCount > 0 {
            instructionBadge("Drag near ball to aim")
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
}
