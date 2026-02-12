import Foundation

struct PhysicsCategory {
    nonisolated static let none:      Int = 0
    nonisolated static let ball:      Int = 1 << 0
    nonisolated static let wall:      Int = 1 << 1
    nonisolated static let hole:      Int = 1 << 2
    nonisolated static let obstacle:  Int = 1 << 3
    nonisolated static let barrier:   Int = 1 << 4
    nonisolated static let club:      Int = 1 << 5
    nonisolated static let surface:   Int = 1 << 6
    nonisolated static let flag:      Int = 1 << 7
}
