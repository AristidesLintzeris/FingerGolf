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

    // Physics tuning (not exposed in UI)
    var ballAtRestThreshold: Float = 0.01
    var holeCaptureVelocityThreshold: Float = 1.5
    var holeCaptureDistanceThreshold: Float = 0.08

    // Base swing power (constant, multiplied by powerPreset)
    let basePower: CGFloat = 0.6

    private let settingsKey = "gameSettings"

    init() {
        load()
    }

    func save() {
        let data: [String: Any] = [
            "barrierMode": barrierMode.rawValue,
            "powerPreset": powerPreset.rawValue,
        ]
        UserDefaults.standard.set(data, forKey: settingsKey)
    }

    func load() {
        guard let data = UserDefaults.standard.dictionary(forKey: settingsKey) else { return }
        if let v = data["barrierMode"] as? String, let mode = BarrierMode(rawValue: v) { barrierMode = mode }
        if let v = data["powerPreset"] as? String, let preset = PowerPreset(rawValue: v) { powerPreset = preset }
    }

    func resetToDefaults() {
        barrierMode = .barrier
        powerPreset = .medium
        save()
    }
}
