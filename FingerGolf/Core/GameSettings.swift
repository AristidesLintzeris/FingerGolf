import Foundation
import Combine

enum PowerPreset: String, CaseIterable {
    case low
    case medium
    case high

    var multiplier: CGFloat {
        switch self {
        case .low: return 0.5
        case .medium: return 1.0
        case .high: return 1.5
        }
    }

    var label: String {
        switch self {
        case .low: return "LOW"
        case .medium: return "MEDIUM"
        case .high: return "HIGH"
        }
    }
}

class GameSettings: ObservableObject {

    enum BarrierMode: String {
        case none
        case barrier
    }

    // Gameplay
    @Published var barrierMode: BarrierMode = .barrier
    @Published var powerPreset: PowerPreset = .medium
    @Published var maxSwingPower: CGFloat = 15.0
    @Published var ballAtRestThreshold: Float = 0.01
    @Published var holeCaptureVelocityThreshold: Float = 0.5
    @Published var holeCaptureDistanceThreshold: Float = 0.05
    @Published var handLostTimeout: TimeInterval = 0.5

    // Kalman filter
    @Published var kalmanProcessNoise: Double = 0.01
    @Published var kalmanMeasurementNoise: Double = 0.1

    // Hand tracking
    @Published var pinchThreshold: CGFloat = 0.08
    @Published var flickMinVelocity: CGFloat = 0.15
    @Published var smoothingFactor: CGFloat = 0.6
    @Published var jumpThreshold: CGFloat = 0.15

    private let settingsKey = "gameSettings"

    init() {
        load()
    }

    func save() {
        let data: [String: Any] = [
            "barrierMode": barrierMode.rawValue,
            "powerPreset": powerPreset.rawValue,
            "maxSwingPower": maxSwingPower,
            "kalmanQ": kalmanProcessNoise,
            "kalmanR": kalmanMeasurementNoise,
            "pinchThreshold": pinchThreshold,
            "flickMinVelocity": flickMinVelocity,
            "smoothingFactor": smoothingFactor,
            "jumpThreshold": jumpThreshold,
        ]
        UserDefaults.standard.set(data, forKey: settingsKey)
    }

    func load() {
        guard let data = UserDefaults.standard.dictionary(forKey: settingsKey) else { return }
        if let v = data["barrierMode"] as? String, let mode = BarrierMode(rawValue: v) { barrierMode = mode }
        if let v = data["powerPreset"] as? String, let preset = PowerPreset(rawValue: v) { powerPreset = preset }
        if let v = data["maxSwingPower"] as? CGFloat { maxSwingPower = v }
        if let v = data["kalmanQ"] as? Double { kalmanProcessNoise = v }
        if let v = data["kalmanR"] as? Double { kalmanMeasurementNoise = v }
        if let v = data["pinchThreshold"] as? CGFloat { pinchThreshold = v }
        if let v = data["flickMinVelocity"] as? CGFloat { flickMinVelocity = v }
        if let v = data["smoothingFactor"] as? CGFloat { smoothingFactor = v }
        if let v = data["jumpThreshold"] as? CGFloat { jumpThreshold = v }
    }

    func resetToDefaults() {
        barrierMode = .barrier
        powerPreset = .medium
        maxSwingPower = 15.0
        kalmanProcessNoise = 0.01
        kalmanMeasurementNoise = 0.1
        pinchThreshold = 0.08
        flickMinVelocity = 0.15
        smoothingFactor = 0.6
        jumpThreshold = 0.15
        save()
    }
}
