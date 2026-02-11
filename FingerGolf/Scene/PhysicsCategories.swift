import Foundation

struct PhysicsCategory {
    static let none:      Int = 0
    static let ball:      Int = 1 << 0
    static let wall:      Int = 1 << 1
    static let hole:      Int = 1 << 2
    static let obstacle:  Int = 1 << 3
    static let barrier:   Int = 1 << 4
    static let club:      Int = 1 << 5
    static let surface:   Int = 1 << 6
}
