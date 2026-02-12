import SwiftUI
import SceneKit

/// SwiftUI overlay that displays trajectory preview as UI elements on top of the 3D scene
/// Shows a dashed line from ball toward aim direction, sized by power
struct TrajectoryOverlay: View {

    let scnView: SCNView?
    let ballPosition: SCNVector3
    let direction: SCNVector3
    let power: Float
    let isVisible: Bool

    private let dotCount: Int = 20
    private let maxLineLength: Float = 3.0

    var body: some View {
        GeometryReader { geometry in
            if isVisible, let scnView = scnView {
                ZStack {
                    ForEach(0..<dotCount, id: \.self) { index in
                        let progress = Float(index + 1) / Float(dotCount)
                        let t = progress * power * maxLineLength

                        if let screenPoint = projectToScreen(
                            position: SCNVector3(
                                ballPosition.x + direction.x * t,
                                0.07,  // Just above ground
                                ballPosition.z + direction.z * t
                            ),
                            scnView: scnView,
                            viewSize: geometry.size
                        ) {
                            Circle()
                                .fill(Color.white.opacity(Double(1.0 - progress * 0.6)))
                                .frame(width: CGFloat(12 - progress * 6), height: CGFloat(12 - progress * 6))  // Larger dots
                                .position(screenPoint)
                        }
                    }
                }
            }
        }
        .allowsHitTesting(false)  // Don't intercept touches
    }

    /// Project 3D world position to 2D screen coordinates
    private func projectToScreen(position: SCNVector3, scnView: SCNView, viewSize: CGSize) -> CGPoint? {
        let projected = scnView.projectPoint(position)

        // Check if point is in front of camera
        guard projected.z < 1.0 && projected.z > 0.0 else { return nil }

        return CGPoint(
            x: CGFloat(projected.x),
            y: CGFloat(projected.y)
        )
    }
}
