import SwiftUI

struct RestartFadeEffect: View {
    let centerPosition: CGPoint
    let onComplete: () -> Void

    @State private var scale: CGFloat = 0.0
    @State private var opacity: Double = 0.0

    var body: some View {
        Circle()
            .fill(.black)
            .frame(width: 50, height: 50)
            .scaleEffect(scale)
            .opacity(opacity)
            .position(centerPosition)
            .onAppear {
                withAnimation(.easeIn(duration: 0.6)) {
                    scale = 50.0  // Expands to cover screen
                    opacity = 1.0
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                    onComplete()
                }
            }
    }
}
