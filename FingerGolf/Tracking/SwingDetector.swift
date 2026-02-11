import Foundation
import Combine

struct SwingResult {
    let power: CGFloat      // 0.0 to 1.0 normalized
    let rawVelocity: CGFloat
}

class SwingDetector: ObservableObject {

    @Published var lastSwingResult: SwingResult?

    private var cancellables = Set<AnyCancellable>()

    init(handTrackingCoordinator: HandTrackingCoordinator) {
        handTrackingCoordinator.$handState
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                if case .flickCompleted(let power) = state {
                    self?.lastSwingResult = SwingResult(power: power, rawVelocity: power)
                }
            }
            .store(in: &cancellables)
    }

    func consumeSwing() -> SwingResult? {
        let result = lastSwingResult
        lastSwingResult = nil
        return result
    }
}
