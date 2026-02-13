import Foundation
import Combine

/// Simplified to match Unity LevelManager shot counting:
/// - shotCount starts at level's max shots
/// - Decremented each time ball stops after a shot
/// - Level fails when shotCount reaches 0
class TurnManager: ObservableObject {

    @Published var shotCount: Int = 0       // Unity: shotCount (remaining shots)
    @Published var strokeCount: Int = 0     // Total strokes taken this hole
    @Published var maxShots: Int = 0        // Starting shot count for this level
    @Published var ballIsMoving: Bool = false

    /// Set up for a new hole with the level's max shot count.
    /// Unity: LevelManager.SpawnLevel sets shotCount = levelDatas[index].shotCount
    func resetForNewHole(maxShots: Int) {
        self.maxShots = maxShots
        shotCount = maxShots
        strokeCount = 0
        ballIsMoving = false
    }

    /// Ball was just shot. Mark as moving.
    func ballShot() {
        ballIsMoving = true
    }

    /// Ball has stopped. Decrement shot count.
    /// Unity: LevelManager.ShotTaken() - called when ball becomes static.
    /// Returns true if shots remain, false if out of shots (level failed).
    @discardableResult
    func shotTaken() -> Bool {
        ballIsMoving = false
        strokeCount += 1

        if shotCount > 0 {
            shotCount -= 1
        }

        return shotCount > 0
    }
}
