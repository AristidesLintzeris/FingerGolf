import SwiftUI

struct MainMenuView: View {

    let courses: [CourseDefinition]
    var onStartCourse: (Int) -> Void

    @State private var selectedCourse: Int = 0

    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            // Title
            VStack(spacing: 8) {
                Text("FINGERGOLF")
                    .font(.custom("Noteworthy-Bold", size: 48))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.green, .mint],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                Text("MINI GOLF WITH HAND GESTURES")
                    .font(.custom("Noteworthy-Light", size: 14))
                    .foregroundStyle(.secondary)
                    .tracking(2)
            }

            Spacer()

            // Course selection
            VStack(spacing: 12) {
                Text("SELECT COURSE")
                    .font(.custom("Noteworthy-Bold", size: 18))
                    .tracking(1)

                ForEach(Array(courses.enumerated()), id: \.offset) { index, course in
                    Button {
                        selectedCourse = index
                    } label: {
                        HStack {
                            Text("\(index + 1)")
                                .font(.custom("Noteworthy-Bold", size: 14))
                                .frame(width: 28, height: 28)
                                .background(selectedCourse == index ? Color.green : Color.gray.opacity(0.3))
                                .foregroundStyle(selectedCourse == index ? .white : .primary)
                                .clipShape(Circle())

                            Text(course.name.uppercased())
                                .font(.custom("Noteworthy-Bold", size: 16))

                            Spacer()

                            Text("PAR \(course.par)")
                                .font(.custom("Noteworthy-Light", size: 13))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            selectedCourse == index
                            ? Color.green.opacity(0.1)
                            : Color.clear
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(selectedCourse == index ? Color.green : Color.gray.opacity(0.2), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)

            Spacer()

            // Play button with UI Pack asset
            Button {
                onStartCourse(selectedCourse)
            } label: {
                Text("PLAY")
                    .font(.custom("Noteworthy-Bold", size: 22))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        Image("GameUI/button_rectangle_depth_gradient")
                            .resizable()
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
    }
}
