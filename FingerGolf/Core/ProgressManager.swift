import Foundation
import Combine

class ProgressManager: ObservableObject {

    private let unlockedKey = "unlockedLevelIndex"
    private let scoresKey = "bestScores"

    @Published var highestUnlockedLevel: Int {
        didSet { UserDefaults.standard.set(highestUnlockedLevel, forKey: unlockedKey) }
    }

    @Published var bestScores: [Int: Int] {
        didSet {
            let encoded = bestScores.reduce(into: [String: Int]()) { $0["\($1.key)"] = $1.value }
            UserDefaults.standard.set(encoded, forKey: scoresKey)
        }
    }

    init() {
        let saved = UserDefaults.standard.integer(forKey: unlockedKey)
        self.highestUnlockedLevel = max(saved, 0)

        if let savedScores = UserDefaults.standard.dictionary(forKey: scoresKey) as? [String: Int] {
            self.bestScores = savedScores.reduce(into: [Int: Int]()) { dict, pair in
                if let key = Int(pair.key) { dict[key] = pair.value }
            }
        } else {
            self.bestScores = [:]
        }
    }

    func isLevelUnlocked(_ index: Int) -> Bool {
        index <= highestUnlockedLevel
    }

    func completeLevel(_ index: Int, strokes: Int, par: Int) {
        if index >= highestUnlockedLevel {
            highestUnlockedLevel = index + 1
        }
        if let existing = bestScores[index] {
            bestScores[index] = min(existing, strokes)
        } else {
            bestScores[index] = strokes
        }
    }

    func starsForLevel(_ index: Int, par: Int) -> Int {
        guard let best = bestScores[index] else { return 0 }
        let diff = best - par
        if diff <= -2 { return 3 }
        if diff <= 0 { return 2 }
        return 1
    }
}
