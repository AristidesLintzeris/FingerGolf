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
                Text("FingerGolf")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.green, .mint],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                Text("Mini Golf with Hand Gestures")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Course selection
            VStack(spacing: 12) {
                Text("Select Course")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))

                ForEach(Array(courses.enumerated()), id: \.offset) { index, course in
                    Button {
                        selectedCourse = index
                    } label: {
                        HStack {
                            Text("\(index + 1)")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .frame(width: 28, height: 28)
                                .background(selectedCourse == index ? Color.green : Color.gray.opacity(0.3))
                                .foregroundStyle(selectedCourse == index ? .white : .primary)
                                .clipShape(Circle())

                            Text(course.name)
                                .font(.system(size: 17, weight: .medium, design: .rounded))

                            Spacer()

                            Text("Par \(course.par)")
                                .font(.system(size: 14, weight: .regular, design: .rounded))
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

            // Play button
            Button {
                onStartCourse(selectedCourse)
            } label: {
                Text("Play")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [.green, .mint],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
    }
}
