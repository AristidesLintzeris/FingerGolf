import SwiftUI

struct LoadingView: View {
    var body: some View {
        ZStack {
            Color(red: 0.35, green: 0.58, blue: 0.78)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Text("FINGER GOLF")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)
                    .scaleEffect(1.5)

                Text("Loading...")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }
}
