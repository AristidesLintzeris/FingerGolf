import SwiftUI

struct ScoreCardView: View {

    let scores: [HoleScore]
    let totalStrokes: Int
    let totalPar: Int
    var onReturnToMenu: () -> Void

    private var totalRelativeToPar: Int { totalStrokes - totalPar }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 20) {
                // Title
                Text("COURSE COMPLETE!")
                    .font(.custom("Noteworthy-Bold", size: 32))

                // Score summary
                VStack(spacing: 4) {
                    Text("TOTAL: \(totalStrokes) STROKES")
                        .font(.custom("Noteworthy-Bold", size: 20))

                    Text(totalRelativeToPar == 0 ? "EVEN PAR" :
                            (totalRelativeToPar > 0 ? "+\(totalRelativeToPar) OVER PAR" : "\(totalRelativeToPar) UNDER PAR"))
                        .font(.custom("Noteworthy-Bold", size: 16))
                        .foregroundStyle(totalRelativeToPar <= 0 ? .green : .orange)
                }

                // Per-hole breakdown
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Text("Hole")
                            .frame(width: 50, alignment: .leading)
                        Text("Par")
                            .frame(width: 40, alignment: .center)
                        Text("Score")
                            .frame(width: 50, alignment: .center)
                        Spacer()
                        Text("Result")
                            .frame(width: 80, alignment: .trailing)
                    }
                    .font(.custom("Noteworthy-Bold", size: 12))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)

                    Divider()

                    ForEach(scores) { score in
                        HStack {
                            Text("\(score.holeNumber)")
                                .frame(width: 50, alignment: .leading)
                            Text("\(score.par)")
                                .frame(width: 40, alignment: .center)
                            Text("\(score.strokes)")
                                .frame(width: 50, alignment: .center)
                                .fontWeight(.semibold)
                            Spacer()
                            Text(score.label)
                                .frame(width: 80, alignment: .trailing)
                                .foregroundStyle(score.relativeToPar <= 0 ? .green : .orange)
                        }
                        .font(.custom("Noteworthy-Bold", size: 14))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                    }
                }
                .background(Color(.systemBackground).opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Return button
                Button {
                    onReturnToMenu()
                } label: {
                    Text("RETURN TO MENU")
                        .font(.custom("Noteworthy-Bold", size: 18))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [.green, .mint],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 20)
            }
            .padding(24)
            .background(.ultraThickMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .padding(.horizontal, 20)

            Spacer()
        }
    }
}
