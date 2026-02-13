import Foundation

struct PhysicsCategory {
    nonisolated static let none:     Int = 0
    nonisolated static let ball:     Int = 1 << 0
    nonisolated static let course:   Int = 1 << 1  // Floor + walls (mesh geometry)
    nonisolated static let hole:     Int = 1 << 2
    nonisolated static let flag:     Int = 1 << 3
}
