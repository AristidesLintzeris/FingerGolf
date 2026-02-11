import Foundation
import Combine

enum TurnState {
    case placingClub       // Player positions club via touch
    case readyToSwing      // Club placed, waiting for swing input
    case swinging          // Swing in progress
    case ballMoving        // Ball is moving, player waits
    case ballStopped       // Ball stopped, checking if in hole
    case holeComplete      // Ball in hole
}

enum TurnEvent {
    case clubPlaced
    case swingStarted
    case ballHit
    case ballStopped
    case ballInHole
    case continuePlay
    case handLost
    case reset
}

class TurnManager: ObservableObject {

    @Published var state: TurnState = .placingClub
    @Published var strokeCount: Int = 0

    func advanceState(_ event: TurnEvent) {
        switch (state, event) {
        case (.placingClub, .clubPlaced):
            state = .readyToSwing

        case (.readyToSwing, .swingStarted):
            state = .swinging

        case (.swinging, .ballHit):
            strokeCount += 1
            state = .ballMoving

        case (.ballMoving, .ballStopped):
            state = .ballStopped

        case (.ballStopped, .ballInHole):
            state = .holeComplete

        case (.ballStopped, .continuePlay):
            state = .placingClub

        case (.readyToSwing, .handLost):
            // Hand tracking lost before swing - reset club, don't count stroke
            state = .placingClub

        case (_, .reset):
            state = .placingClub

        default:
            break
        }
    }

    func resetForNewHole() {
        strokeCount = 0
        state = .placingClub
    }
}
