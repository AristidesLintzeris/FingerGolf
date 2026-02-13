import AVFoundation
import UIKit

class AudioManager {

    static let shared = AudioManager()

    // MARK: - Haptics

    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private let successNotification = UINotificationFeedbackGenerator()

    // MARK: - Audio

    private var effectsPlayer: AVAudioPlayer?
    private var isMuted: Bool = false

    private init() {
        // Prepare haptic engines for lower latency
        lightImpact.prepare()
        mediumImpact.prepare()
        heavyImpact.prepare()
        successNotification.prepare()

        // Configure audio session for mixing with other apps
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    // MARK: - Haptic Feedback

    func hitBall(power: CGFloat) {
        if power > 0.7 {
            heavyImpact.impactOccurred(intensity: min(power, 1.0))
        } else if power > 0.3 {
            mediumImpact.impactOccurred(intensity: min(power, 1.0))
        } else {
            lightImpact.impactOccurred(intensity: max(power, 0.4))
        }
    }

    func wallBounce() {
        lightImpact.impactOccurred(intensity: 0.6)
    }

    func ballInHole() {
        successNotification.notificationOccurred(.success)
    }

    func ballFellOff() {
        successNotification.notificationOccurred(.error)
    }

    func uiTap() {
        lightImpact.impactOccurred(intensity: 0.3)
    }
}
