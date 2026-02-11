import SwiftUI

struct PermissionView: View {

    let onContinueWithoutCamera: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "camera.fill")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                Text("CAMERA ACCESS REQUIRED")
                    .font(.custom("Noteworthy-Bold", size: 22))

                Text("FINGERGOLF USES YOUR FRONT CAMERA TO TRACK HAND GESTURES FOR SWINGING THE GOLF CLUB.")
                    .font(.custom("Noteworthy-Light", size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }

            VStack(spacing: 12) {
                Button {
                    openSettings()
                } label: {
                    Text("OPEN SETTINGS")
                        .font(.custom("Noteworthy-Bold", size: 18))
                        .foregroundStyle(.white)
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
                        .font(.custom("Noteworthy-Bold", size: 14))
                        .foregroundStyle(.secondary)
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
