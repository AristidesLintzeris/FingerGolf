import Foundation
import Combine

struct HoleScore: Identifiable {
    let id = UUID()
    let holeNumber: Int
    let par: Int
    let strokes: Int

    var relativeToPar: Int { strokes - par }

    var label: String {
        switch relativeToPar {
        case ..<(-2): return "Eagle or better"
        case -2: return "Eagle"
        case -1: return "Birdie"
        case 0: return "Par"
        case 1: return "Bogey"
        case 2: return "Double Bogey"
        default: return "+\(relativeToPar)"
        }
    }
}

class ScoringManager: ObservableObject {

    @Published var currentHole: Int = 1
    @Published var scores: [HoleScore] = []

    var totalStrokes: Int {
        scores.reduce(0) { $0 + $1.strokes }
    }

    var totalPar: Int {
        scores.reduce(0) { $0 + $1.par }
    }

    var totalRelativeToPar: Int {
        totalStrokes - totalPar
    }

    func recordHoleScore(par: Int, strokes: Int) {
        let score = HoleScore(
            holeNumber: currentHole,
            par: par,
            strokes: strokes
        )
        scores.append(score)
        currentHole += 1
    }

    func reset() {
        currentHole = 1
        scores.removeAll()
    }
}
