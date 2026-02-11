import SwiftUI

struct PermissionView: View {

    let onContinueWithoutCamera: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "camera.fill")
                .font(.system(size: 60))
                .foregroundStyle(.white.opacity(0.5))
                .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 2)

            VStack(spacing: 8) {
                Text("CAMERA ACCESS REQUIRED")
                    .headingStyle(size: 22)

                Text("FINGERGOLF USES YOUR FRONT CAMERA TO TRACK HAND GESTURES FOR SWINGING THE GOLF CLUB.")
                    .lightStyle(size: 14)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }

            VStack(spacing: 12) {
                Button {
                    openSettings()
                } label: {
                    Text("OPEN SETTINGS")
                        .headingStyle(size: 18)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            Image("GameUI/button_rectangle_depth_gradient")
                                .resizable()
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                Button {
                    onContinueWithoutCamera()
                } label: {
                    Text("CONTINUE WITH TOUCH CONTROLS")
                        .bodyStyle(size: 14)
                        .opacity(0.7)
                }
            }
            .padding(.horizontal, 40)

            Spacer()
        }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
