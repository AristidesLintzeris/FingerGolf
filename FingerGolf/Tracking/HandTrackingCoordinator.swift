import Foundation
import Combine
import UIKit

enum HandState: Equatable {
    case noHand
    case handDetected
    case pinching
    case flickInProgress
    case flickCompleted(power: CGFloat)

    static func == (lhs: HandState, rhs: HandState) -> Bool {
        switch (lhs, rhs) {
        case (.noHand, .noHand),
             (.handDetected, .handDetected),
             (.pinching, .pinching),
             (.flickInProgress, .flickInProgress):
            return true
        case (.flickCompleted(let a), .flickCompleted(let b)):
            return a == b
        default:
            return false
        }
    }
}

class HandTrackingCoordinator: ObservableObject {

    // MARK: - Published State

    @Published var handState: HandState = .noHand
    @Published var thumbScreenPosition: CGPoint?
    @Published var indexScreenPosition: CGPoint?

    // MARK: - Configuration

    var pinchThreshold: CGFloat = 0.08    // normalized distance to consider "pinching"
    var flickMinVelocity: CGFloat = 0.15   // min separation velocity for a flick
    var powerPreset: PowerPreset = .medium
    private let handLostTimeout: TimeInterval = 0.5

    // MARK: - Internal State

    private var handLostTimer: Timer?
    private var pinchStartDistance: CGFloat = 0
    private var pinchStartTime: TimeInterval = 0
    private var lastDistance: CGFloat = 0
    private var lastDistanceTime: TimeInterval = 0
    private var velocityHistory: [(velocity: CGFloat, time: TimeInterval)] = []
    private let velocityKalman = KalmanScalar(q: 0.01, r: 0.1)

    private var cancellables = Set<AnyCancellable>()
    private var viewSize: CGSize = UIScreen.main.bounds.size

    // MARK: - Initialization

    init(visionEngine: VisionEngine) {
        visionEngine.$handLandmarks
            .receive(on: RunLoop.main)
            .sink { [weak self] landmarks in
                self?.processLandmarks(landmarks)
            }
            .store(in: &cancellables)
    }

    func setViewSize(_ size: CGSize) {
        viewSize = size
    }

    // MARK: - Processing

    private func processLandmarks(_ landmarks: [HandLandmarks]) {
        // Use first detected hand (works with either hand)
        guard let hand = landmarks.first,
              let thumb = hand.thumbTip,
              let index = hand.indexTip else {
            handleHandLost()
            return
        }

        // Hand is detected - cancel lost timer
        handLostTimer?.invalidate()
        handLostTimer = nil

        // Convert to screen coordinates
        thumbScreenPosition = convertToScreenCoordinates(point: thumb)
        indexScreenPosition = convertToScreenCoordinates(point: index)

        // Calculate pinch distance
        let distance = sqrt(pow(thumb.x - index.x, 2) + pow(thumb.y - index.y, 2))
        let now = CACurrentMediaTime()

        switch handState {
        case .noHand:
            handState = .handDetected
            lastDistance = distance
            lastDistanceTime = now

        case .handDetected:
            if distance < pinchThreshold {
                handState = .pinching
                pinchStartDistance = distance
                pinchStartTime = now
                lastDistance = distance
                lastDistanceTime = now
                velocityHistory.removeAll()
            }
            lastDistance = distance
            lastDistanceTime = now

        case .pinching:
            if distance > pinchThreshold {
                // Fingers are separating - flick may be starting
                handState = .flickInProgress
                pinchStartDistance = lastDistance
                pinchStartTime = now
                lastDistance = distance
                lastDistanceTime = now
            }

        case .flickInProgress:
            // Track separation velocity
            let dt = now - lastDistanceTime
            if dt > 0 {
                let rawVelocity = (distance - lastDistance) / dt
                let smoothedVelocity = CGFloat(velocityKalman.update(Double(rawVelocity)))

                velocityHistory.append((velocity: smoothedVelocity, time: now))

                // Keep only recent history (last 0.5s)
                velocityHistory = velocityHistory.filter { now - $0.time < 0.5 }
            }

            lastDistance = distance
            lastDistanceTime = now

            // Check if flick is complete (velocity peaked and is decreasing, or fingers far apart)
            let totalSeparation = distance - pinchStartDistance
            if totalSeparation > 0.05 {
                let peakVelocity = velocityHistory.map(\.velocity).max() ?? 0
                if peakVelocity > flickMinVelocity {
                    let power = velocityToPower(peakVelocity)
                    handState = .flickCompleted(power: power)
                }
            }

            // If fingers come back together, cancel
            if distance < pinchThreshold * 0.8 {
                handState = .pinching
                velocityHistory.removeAll()
            }

        case .flickCompleted:
            // Stay in completed state until reset
            break
        }
    }

    // MARK: - Hand Lost

    private func handleHandLost() {
        thumbScreenPosition = nil
        indexScreenPosition = nil

        if handLostTimer == nil {
            handLostTimer = Timer.scheduledTimer(withTimeInterval: handLostTimeout, repeats: false) { [weak self] _ in
                guard let self else { return }
                self.handState = .noHand
                self.velocityHistory.removeAll()
            }
        }
    }

    // MARK: - Power Mapping

    private func velocityToPower(_ velocity: CGFloat) -> CGFloat {
        // Sigmoid-like mapping: slow flick → low power, fast flick → high power
        let maxVelocity: CGFloat = 2.0
        let normalized = min(velocity / maxVelocity, 1.0)
        let basePower = pow(normalized, 0.7) // curve for better control feel
        return min(basePower * powerPreset.multiplier, 1.0)
    }

    // MARK: - Coordinate Conversion

    private func convertToScreenCoordinates(point: CGPoint) -> CGPoint {
        let bufferRatio: CGFloat = 4.0 / 3.0 // Portrait camera buffer
        let viewRatio = viewSize.height / viewSize.width

        if viewRatio > bufferRatio {
            // Screen is taller than buffer (most iPhones)
            let scale = viewSize.height
            let virtualWidth = scale / bufferRatio
            let xOffset = (virtualWidth - viewSize.width) / 2.0

            return CGPoint(
                x: (1.0 - point.x) * virtualWidth - xOffset, // Mirror for front camera
                y: (1.0 - point.y) * viewSize.height
            )
        } else {
            // Screen is wider than buffer
            let scale = viewSize.width
            let virtualHeight = scale * bufferRatio
            let yOffset = (virtualHeight - viewSize.height) / 2.0

            return CGPoint(
                x: (1.0 - point.x) * viewSize.width,
                y: (1.0 - point.y) * virtualHeight - yOffset
            )
        }
    }

    // MARK: - Reset

    func resetForNewSwing() {
        if case .flickCompleted = handState {
            handState = .handDetected
        }
        velocityHistory.removeAll()
        velocityKalman.reset()
    }

    func updateKalman(q: Double, r: Double) {
        velocityKalman.q = q
        velocityKalman.r = r
        velocityKalman.reset()
    }
}
