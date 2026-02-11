import SwiftUI

struct MainMenuView: View {

    var onStartPressed: () -> Void
    var onSettingsPressed: () -> Void

    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            // Club logo
            Image("club-green")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 120, height: 120)

            // Title
            VStack(spacing: 8) {
                Text("FINGERGOLF")
                    .titleStyle(size: 48)

                Text("MINI GOLF WITH HAND GESTURES")
                    .lightStyle(size: 14)
                    .tracking(2)
            }

            Spacer()

            // Buttons
            VStack(spacing: 14) {
                Button(action: onStartPressed) {
                    Text("START")
                        .headingStyle(size: 22)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            Image("GameUI/button_rectangle_depth_gradient")
                                .resizable()
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }

                Button(action: onSettingsPressed) {
                    HStack(spacing: 8) {
                        Image(systemName: "gearshape.fill")
                        Text("SETTINGS")
                    }
                    .bodyStyle(size: 16)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        Image("GameUI/button_rectangle_depth_flat")
                            .resizable()
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 50)
        }
    }
}
