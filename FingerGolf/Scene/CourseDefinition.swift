import SceneKit

struct CourseDefinition: Codable {
    let name: String
    let par: Int
    let pieces: [PiecePlacement]
    let ballStart: GridPosition
    let holePosition: GridPosition
    let holeModel: String?

    init(name: String, par: Int, pieces: [PiecePlacement], ballStart: GridPosition, holePosition: GridPosition, holeModel: String? = "hole-round") {
        self.name = name
        self.par = par
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
