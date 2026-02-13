import SceneKit

struct CourseDefinition: Codable {
    let name: String
    let par: Int
    let shotCount: Int      // Unity: LevelData.shotCount - max shots allowed
    let pieces: [PiecePlacement]
    let ballStart: GridPosition
    let holePosition: GridPosition
    let holeModel: String?

    init(name: String, par: Int, shotCount: Int? = nil, pieces: [PiecePlacement], ballStart: GridPosition, holePosition: GridPosition, holeModel: String? = "hole-round") {
        self.name = name
        self.par = par
        self.shotCount = shotCount ?? (par + 3)  // Default: par + 3 shots
        self.pieces = pieces
        self.ballStart = ballStart
        self.holePosition = holePosition
        self.holeModel = holeModel
    }
}

struct PiecePlacement: Codable {
    let model: String
    let position: GridPosition
    let rotation: Int  // 0, 90, 180, 270 degrees

    init(model: String, x: Int, z: Int, rotation: Int = 0) {
        self.model = model
        self.position = GridPosition(x: x, z: z)
        self.rotation = rotation
    }
}

struct GridPosition: Codable {
    let x: Int
    let z: Int

    var scenePosition: SCNVector3 {
        SCNVector3(Float(x), 0, Float(z))
    }
}
