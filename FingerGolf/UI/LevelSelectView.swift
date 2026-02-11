import SwiftUI

struct LevelSelectView: View {

    let courses: [CourseDefinition]
    @ObservedObject var progressManager: ProgressManager
    var onSelectLevel: (Int) -> Void
    var onBack: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .bodyStyle(size: 22)
                        .frame(width: 44, height: 44)
                }

                Spacer()

                Text("SELECT LEVEL")
                    .headingStyle(size: 28)

                Spacer()

                Color.clear.frame(width: 44, height: 44)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(Array(courses.enumerated()), id: \.offset) { index, course in
                        let unlocked = progressManager.isLevelUnlocked(index)
                        let stars = progressManager.starsForLevel(index, par: course.par)

                        Button {
                            if unlocked { onSelectLevel(index) }
                        } label: {
                            HStack(spacing: 12) {
                                Text("\(index + 1)")
                                    .bodyStyle(size: 16)
                                    .frame(width: 36, height: 36)
                                    .background(unlocked ? Color.green : Color.gray.opacity(0.4))
                                    .clipShape(Circle())

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(course.name.uppercased())
                                        .bodyStyle(size: 16)

                                    Text("PAR \(course.par)")
                                        .lightStyle(size: 12)
                                }

                                Spacer()

                                if !unlocked {
                                    Image(systemName: "lock.fill")
                                        .foregroundStyle(.gray)
                                        .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                                } else {
                                    HStack(spacing: 2) {
                                        ForEach(0..<3, id: \.self) { i in
                                            Image(i < stars ? "GameUI/star" : "GameUI/star_outline")
                                                .resizable()
                                                .frame(width: 18, height: 18)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(
                                unlocked
                                ? Color.white.opacity(0.1)
                                : Color.gray.opacity(0.05)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(
                                        unlocked ? Color.green.opacity(0.4) : Color.gray.opacity(0.15),
                                        lineWidth: 1
                                    )
                            )
                        }
                        .disabled(!unlocked)
                        .opacity(unlocked ? 1.0 : 0.5)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
    }
}
