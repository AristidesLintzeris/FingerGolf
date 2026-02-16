import SceneKit

class CourseBuilder {

    private let assetCatalog = AssetCatalog.shared

    func buildCourse(from definition: CourseDefinition) -> SCNNode {
        let courseRoot = SCNNode()
        courseRoot.name = "course_root"

        // Place all course pieces
        for piece in definition.pieces {
            guard let node = assetCatalog.loadPiece(named: piece.model) else {
                print("CourseBuilder: Skipping missing piece '\(piece.model)'")
                continue
            }
            node.position = piece.position.scenePosition
            node.eulerAngles.y = Float(piece.rotation) * .pi / 180.0
            courseRoot.addChildNode(node)
        }

        // Add flag at hole position (the flag is the win target — no separate hole model)
        if let flagNode = assetCatalog.loadPiece(named: "flag-red") {
            flagNode.position = definition.holePosition.scenePosition
            flagNode.name = "flag"
            courseRoot.addChildNode(flagNode)
        }

        return courseRoot
    }

    func computeCourseBounds(_ courseNode: SCNNode) -> (min: SCNVector3, max: SCNVector3) {
        let (minBound, maxBound) = courseNode.boundingBox
        return (minBound, maxBound)
    }

    func computeCourseCenter(_ courseNode: SCNNode) -> SCNVector3 {
        let (minBound, maxBound) = courseNode.boundingBox
        return SCNVector3(
            (minBound.x + maxBound.x) / 2,
            0,
            (minBound.z + maxBound.z) / 2
        )
    }
}
