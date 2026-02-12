import SwiftUI

struct LeaderboardView: View {

    @ObservedObject var cloudKitManager: CloudKitManager
    let courseName: String
    let playerStrokes: Int
    let par: Int
    var onDone: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            VStack(spacing: 16) {
                Text("LEADERBOARD")
                    .headingStyle(size: 24)

                Text(courseName.uppercased())
                    .bodyStyle(size: 16)

                Text("YOUR SCORE: \(playerStrokes) STROKES")
                    .bodyStyle(size: 18)
                    .foregroundStyle(playerStrokes <= par ? .green : .orange)

                // Top 10 entries
                VStack(spacing: 0) {
                    HStack {
                        Text("#")
                            .frame(width: 30, alignment: .leading)
                        Text("PLAYER")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("STROKES")
                            .frame(width: 70, alignment: .trailing)
                    }
                    .lightStyle(size: 12)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)

                    Divider().background(.white.opacity(0.3))

                    ForEach(Array(cloudKitManager.leaderboard.enumerated()), id: \.element.id) { index, entry in
                        HStack {
                            Text("\(index + 1)")
                                .frame(width: 30, alignment: .leading)
                            Text(entry.playerName)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text("\(entry.strokes)")
                                .frame(width: 70, alignment: .trailing)
                        }
                        .bodyStyle(size: 14)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            entry.strokes == playerStrokes
                            ? Color.green.opacity(0.1) : Color.clear
                        )
                    }

                    if cloudKitManager.leaderboard.isEmpty {
                        Text("Be the first to set a score!")
                            .lightStyle(size: 14)
                            .padding(.vertical, 20)
                    }
                }
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                Button(action: onDone) {
                    Text("DONE")
                        .headingStyle(size: 18)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            Image("GameUI/button_rectangle_depth_gradient")
                                .resizable()
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
            .padding(24)
            .background(.ultraThickMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .padding(.horizontal, 20)

            Spacer()
        }
    }
}
