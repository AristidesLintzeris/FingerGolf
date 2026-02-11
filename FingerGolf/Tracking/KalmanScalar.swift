import Foundation

class KalmanScalar {

    // MARK: - Properties

    private var x: Double = 0.0 // State
    private var p: Double = 1.0 // Covariance
    private let q: Double // Process noise
    private let r: Double // Measurement noise

    // MARK: - Initialization

    init(q: Double = 0.005, r: Double = 0.05) {
        self.q = q
        self.r = r
    }

    // MARK: - Filtering

    func update(_ measurement: Double) -> Double {
        // Prediction
        let p_pred = p + q

        // Update
        let kalmanGain = p_pred / (p_pred + r)
        x = x + kalmanGain * (measurement - x)
        p = (1 - kalmanGain) * p_pred

        return x
    }

    func reset() {
        x = 0.0
        p = 1.0
    }
}
