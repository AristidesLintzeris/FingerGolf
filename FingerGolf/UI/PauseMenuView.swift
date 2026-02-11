import SwiftUI

struct PauseMenuView: View {

    var onResume: () -> Void
    var onRestart: () -> Void
    var onSettings: () -> Void
    var onQuit: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Text("PAUSED")
                .titleStyle(size: 36)

            VStack(spacing: 12) {
                pauseButton("RESUME", icon: "play.fill", tint: .green, action: onResume)
                pauseButton("RESTART HOLE", icon: "arrow.counterclockwise", tint: .green, action: onRestart)
                pauseButton("SETTINGS", icon: "gearshape.fill", tint: .blue, action: onSettings)
                pauseButton("QUIT TO MENU", icon: "house.fill", tint: .red, action: onQuit)
            }
            .padding(.horizontal, 20)
        }
        .padding(30)
        .background(.ultraThickMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .padding(.horizontal, 30)
    }

    private func pauseButton(_ title: String, icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .frame(width: 24)
                Text(title)
                Spacer()
            }
            .bodyStyle(size: 16)
            .padding(.vertical, 14)
            .padding(.horizontal, 20)
            .background(tint.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}
