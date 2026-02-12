import SceneKit
import Combine
import Metal

enum EditorTool: String, CaseIterable {
    case ball = "Ball"
    case hole = "Hole"
    case eraser = "Eraser"

    var icon: String {
        switch self {
        case .ball: return "circle.fill"
        case .hole: return "flag.fill"
        case .eraser: return "eraser.fill"
        }
    }

    var color: UIColor {
        switch self {
        case .ball: return .systemRed
        case .hole: return .systemOrange
        case .eraser: return .systemPink
        }
    }
}

class EditorController: ObservableObject {

    // MARK: - Published State

    @Published var pieces: [PiecePlacement] = []
    @Published var selectedPieceIndex: Int? = nil
    @Published var selectedPieceModel: String? = nil
    @Published var ballStartPosition: GridPosition = GridPosition(x: 0, z: 0)
    @Published var holeGridPosition: GridPosition = GridPosition(x: 0, z: 3)
    @Published var par: Int = 3
    @Published var courseName: String = "My Course"
    @Published var cameraDirectionLabel: String = "N"
    @Published var activeTool: EditorTool? = nil
    @Published var canUndo: Bool = false
    @Published var canRedo: Bool = false
    @Published var lastUsedPieceModel: String? = nil

    // MARK: - Undo/Redo

    private enum EditorAction {
        case place(PiecePlacement)
        case delete(PiecePlacement)
        case rotate(Int, Int, Int) // index, oldRotation, newRotation
        case setBall(GridPosition, GridPosition) // old, new
        case setHole(GridPosition, GridPosition) // old, new
    }

    private var undoStack: [EditorAction] = []
    private var redoStack: [EditorAction] = []

    // MARK: - Scene References

    weak var sceneManager: SceneManager?

    // MARK: - Scene Nodes

    let editorRootNode: SCNNode
    private var ghostNode: SCNNode?
    private var placedNodes: [SCNNode] = []
    private var gridNode: SCNNode?
    private var ballMarkerNode: SCNNode?
    private var holeMarkerNode: SCNNode?
    private var selectionHighlightNode: SCNNode?

    // Current ghost state
    private var ghostRotation: Int = 0

    // Thumbnail cache
    private var thumbnailCache: [String: UIImage] = [:]
    private let directionLabels = ["N", "E", "S", "W"]

    // MARK: - Init

    init() {
        editorRootNode = SCNNode()
        editorRootNode.name = "editor_root"

        setupGrid()
        setupMarkers()
    }

    // MARK: - Grid

    private func setupGrid() {
        let gridContainer = SCNNode()
        gridContainer.name = "editor_grid"

        let gridSize = 20
        let lineMaterial = SCNMaterial()
        lineMaterial.diffuse.contents = UIColor.white.withAlphaComponent(0.15)
        lineMaterial.lightingModel = .constant

        for i in -gridSize / 2...gridSize / 2 {
            let hLine = SCNBox(width: CGFloat(gridSize), height: 0.002,
                               length: 0.002, chamferRadius: 0)
            hLine.firstMaterial = lineMaterial
            let hNode = SCNNode(geometry: hLine)
            hNode.position = SCNVector3(0, 0.001, Float(i))
            gridContainer.addChildNode(hNode)

            let vLine = SCNBox(width: 0.002, height: 0.002,
                               length: CGFloat(gridSize), chamferRadius: 0)
            vLine.firstMaterial = lineMaterial
            let vNode = SCNNode(geometry: vLine)
            vNode.position = SCNVector3(Float(i), 0.001, 0)
            gridContainer.addChildNode(vNode)
        }

        gridNode = gridContainer
        editorRootNode.addChildNode(gridContainer)
    }

    private func setupMarkers() {
        // Ball start marker
        let ballGeom = SCNSphere(radius: 0.04)
        let ballMat = SCNMaterial()
        ballMat.diffuse.contents = UIColor.red.withAlphaComponent(0.5)
        ballMat.lightingModel = .constant
        ballGeom.firstMaterial = ballMat
        ballMarkerNode = SCNNode(geometry: ballGeom)
        ballMarkerNode?.position = SCNVector3(Float(ballStartPosition.x), 0.08, Float(ballStartPosition.z))
        ballMarkerNode?.name = "editor_ball_marker"
        editorRootNode.addChildNode(ballMarkerNode!)

        // Hole marker
        let holeGeom = SCNCylinder(radius: 0.06, height: 0.01)
        let holeMat = SCNMaterial()
        holeMat.diffuse.contents = UIColor.black.withAlphaComponent(0.6)
        holeMat.lightingModel = .constant
        holeGeom.firstMaterial = holeMat
        holeMarkerNode = SCNNode(geometry: holeGeom)
        holeMarkerNode?.position = SCNVector3(Float(holeGridPosition.x), 0.01, Float(holeGridPosition.z))
        holeMarkerNode?.name = "editor_hole_marker"
        editorRootNode.addChildNode(holeMarkerNode!)

        // Selection highlight ring
        let ring = SCNTorus(ringRadius: 0.4, pipeRadius: 0.01)
        let ringMat = SCNMaterial()
        ringMat.diffuse.contents = UIColor.green.withAlphaComponent(0.6)
        ringMat.lightingModel = .constant
        ring.firstMaterial = ringMat
        selectionHighlightNode = SCNNode(geometry: ring)
        selectionHighlightNode?.isHidden = true
        selectionHighlightNode?.name = "editor_selection"
        editorRootNode.addChildNode(selectionHighlightNode!)
    }

    // MARK: - Camera Control

    func cycleCamera() {
        sceneManager?.rotateToNextAngle()
        updateCameraLabel()
    }

    func updateCameraLabel() {
        guard let sm = sceneManager else { return }
        cameraDirectionLabel = directionLabels[sm.getCurrentAngleIndex()]
    }

    // MARK: - Piece Selection (from palette)

    func selectPieceToPlace(_ modelName: String) {
        if let current = selectedPieceModel, current != modelName {
            lastUsedPieceModel = current
        }
        selectedPieceModel = modelName
        selectedPieceIndex = nil
        activeTool = nil
        selectionHighlightNode?.isHidden = true
        ghostRotation = 0

        ghostNode?.removeFromParentNode()
        if let node = AssetCatalog.shared.loadPiece(named: modelName) {
            node.opacity = 0.4
            node.name = "ghost_piece"
            node.position = SCNVector3(0, 0, 0)
            ghostNode = node
            editorRootNode.addChildNode(node)
        }
    }

    func deselectPiece() {
        selectedPieceModel = nil
        selectedPieceIndex = nil
        ghostNode?.removeFromParentNode()
        ghostNode = nil
        selectionHighlightNode?.isHidden = true
    }

    // MARK: - Grid Interaction

    func cycleTool() {
        guard let current = activeTool,
              let idx = EditorTool.allCases.firstIndex(of: current) else {
            activeTool = .ball
            return
        }
        let next = (idx + 1) % EditorTool.allCases.count
        activeTool = EditorTool.allCases[next]
    }

    func handleEditorTap(at worldPosition: SCNVector3) {
        let gridX = Int(round(worldPosition.x))
        let gridZ = Int(round(worldPosition.z))

        // Tool mode overrides piece placement
        if let tool = activeTool {
            switch tool {
            case .ball:
                let oldPos = ballStartPosition
                ballStartPosition = GridPosition(x: gridX, z: gridZ)
                ballMarkerNode?.position = SCNVector3(Float(gridX), 0.08, Float(gridZ))
                pushUndo(.setBall(oldPos, ballStartPosition))
            case .hole:
                let oldPos = holeGridPosition
                holeGridPosition = GridPosition(x: gridX, z: gridZ)
                holeMarkerNode?.position = SCNVector3(Float(gridX), 0.01, Float(gridZ))
                pushUndo(.setHole(oldPos, holeGridPosition))
            case .eraser:
                if let index = pieces.firstIndex(where: {
                    $0.position.x == gridX && $0.position.z == gridZ
                }) {
                    let deleted = pieces[index]
                    placedNodes[index].removeFromParentNode()
                    placedNodes.remove(at: index)
                    pieces.remove(at: index)
                    pushUndo(.delete(deleted))
                    if selectedPieceIndex == index {
                        selectedPieceIndex = nil
                        selectionHighlightNode?.isHidden = true
                    } else if let sel = selectedPieceIndex, sel > index {
                        selectedPieceIndex = sel - 1
                    }
                }
            }
            return
        }

        if selectedPieceModel != nil {
            placePieceAtGrid(x: gridX, z: gridZ)
        } else {
            if let currentIndex = selectedPieceIndex,
               pieces[currentIndex].position.x == gridX && pieces[currentIndex].position.z == gridZ {
                rotateRight()
            } else {
                selectPieceAt(gridX: gridX, gridZ: gridZ)
            }
        }
    }

    func handleEditorDrag(at worldPosition: SCNVector3) {
        guard let ghost = ghostNode else { return }
        let gridX = Int(round(worldPosition.x))
        let gridZ = Int(round(worldPosition.z))
        ghost.position = SCNVector3(Float(gridX), 0, Float(gridZ))
    }

    // MARK: - Placement

    private func placePieceAtGrid(x: Int, z: Int) {
        guard let modelName = selectedPieceModel else { return }

        if let existingIndex = pieces.firstIndex(where: {
            $0.position.x == x && $0.position.z == z
        }) {
            placedNodes[existingIndex].removeFromParentNode()
            placedNodes.remove(at: existingIndex)
            pieces.remove(at: existingIndex)
        }

        let placement = PiecePlacement(model: modelName, x: x, z: z, rotation: ghostRotation)
        pieces.append(placement)
        pushUndo(.place(placement))

        if let node = AssetCatalog.shared.loadPiece(named: modelName) {
            node.position = SCNVector3(Float(x), 0, Float(z))
            node.eulerAngles.y = Float(ghostRotation) * .pi / 180.0
            node.name = "placed_piece"
            editorRootNode.addChildNode(node)
            placedNodes.append(node)
        }
    }

    // MARK: - Selection

    private func selectPieceAt(gridX: Int, gridZ: Int) {
        if let index = pieces.firstIndex(where: {
            $0.position.x == gridX && $0.position.z == gridZ
        }) {
            selectedPieceIndex = index
            selectedPieceModel = nil
            ghostNode?.removeFromParentNode()
            ghostNode = nil

            selectionHighlightNode?.isHidden = false
            selectionHighlightNode?.position = SCNVector3(Float(gridX), 0.05, Float(gridZ))
        } else {
            selectedPieceIndex = nil
            selectionHighlightNode?.isHidden = true
        }
    }

    // MARK: - Rotation

    func rotateRight() {
        if selectedPieceModel != nil {
            ghostRotation = (ghostRotation + 90) % 360
            ghostNode?.eulerAngles.y = Float(ghostRotation) * .pi / 180.0
        } else if let index = selectedPieceIndex, index < pieces.count {
            let piece = pieces[index]
            let oldRotation = piece.rotation
            let newRotation = (oldRotation + 90) % 360
            pieces[index] = PiecePlacement(
                model: piece.model, x: piece.position.x,
                z: piece.position.z, rotation: newRotation
            )
            placedNodes[index].eulerAngles.y = Float(newRotation) * .pi / 180.0
            pushUndo(.rotate(index, oldRotation, newRotation))
        }
    }

    func rotateLeft() {
        if selectedPieceModel != nil {
            ghostRotation = (ghostRotation - 90 + 360) % 360
            ghostNode?.eulerAngles.y = Float(ghostRotation) * .pi / 180.0
        } else if let index = selectedPieceIndex, index < pieces.count {
            let piece = pieces[index]
            let oldRotation = piece.rotation
            let newRotation = (oldRotation - 90 + 360) % 360
            pieces[index] = PiecePlacement(
                model: piece.model, x: piece.position.x,
                z: piece.position.z, rotation: newRotation
            )
            placedNodes[index].eulerAngles.y = Float(newRotation) * .pi / 180.0
            pushUndo(.rotate(index, oldRotation, newRotation))
        }
    }

    func rotateSelectedPiece() {
        rotateRight()
    }

    func deleteSelectedPiece() {
        guard let index = selectedPieceIndex, index < pieces.count else { return }
        placedNodes[index].removeFromParentNode()
        placedNodes.remove(at: index)
        pieces.remove(at: index)
        selectedPieceIndex = nil
        selectionHighlightNode?.isHidden = true
    }

    func setBallStartAtSelected() {
        guard let index = selectedPieceIndex, index < pieces.count else { return }
        ballStartPosition = pieces[index].position
        ballMarkerNode?.position = SCNVector3(
            Float(ballStartPosition.x), 0.08, Float(ballStartPosition.z)
        )
    }

    func setHoleAtSelected() {
        guard let index = selectedPieceIndex, index < pieces.count else { return }
        holeGridPosition = pieces[index].position
        holeMarkerNode?.position = SCNVector3(
            Float(holeGridPosition.x), 0.01, Float(holeGridPosition.z)
        )
    }

    // MARK: - Undo / Redo

    private func pushUndo(_ action: EditorAction) {
        undoStack.append(action)
        redoStack.removeAll()
        canUndo = true
        canRedo = false
    }

    private func updateUndoRedoState() {
        canUndo = !undoStack.isEmpty
        canRedo = !redoStack.isEmpty
    }

    func undo() {
        guard let action = undoStack.popLast() else { return }
        applyReverse(action)
        redoStack.append(action)
        updateUndoRedoState()
    }

    func redo() {
        guard let action = redoStack.popLast() else { return }
        applyForward(action)
        undoStack.append(action)
        updateUndoRedoState()
    }

    private func applyReverse(_ action: EditorAction) {
        switch action {
        case .place(let placement):
            // Undo place = remove the piece
            if let index = pieces.firstIndex(where: {
                $0.position.x == placement.position.x && $0.position.z == placement.position.z
                && $0.model == placement.model
            }) {
                placedNodes[index].removeFromParentNode()
                placedNodes.remove(at: index)
                pieces.remove(at: index)
                selectedPieceIndex = nil
                selectionHighlightNode?.isHidden = true
            }

        case .delete(let placement):
            // Undo delete = re-add the piece
            pieces.append(placement)
            if let node = AssetCatalog.shared.loadPiece(named: placement.model) {
                node.position = placement.position.scenePosition
                node.eulerAngles.y = Float(placement.rotation) * .pi / 180.0
                node.name = "placed_piece"
                editorRootNode.addChildNode(node)
                placedNodes.append(node)
            }

        case .rotate(let index, let oldRotation, _):
            guard index < pieces.count else { return }
            let piece = pieces[index]
            pieces[index] = PiecePlacement(
                model: piece.model, x: piece.position.x,
                z: piece.position.z, rotation: oldRotation
            )
            placedNodes[index].eulerAngles.y = Float(oldRotation) * .pi / 180.0

        case .setBall(let oldPos, _):
            ballStartPosition = oldPos
            ballMarkerNode?.position = SCNVector3(Float(oldPos.x), 0.08, Float(oldPos.z))

        case .setHole(let oldPos, _):
            holeGridPosition = oldPos
            holeMarkerNode?.position = SCNVector3(Float(oldPos.x), 0.01, Float(oldPos.z))
        }
    }

    private func applyForward(_ action: EditorAction) {
        switch action {
        case .place(let placement):
            pieces.append(placement)
            if let node = AssetCatalog.shared.loadPiece(named: placement.model) {
                node.position = placement.position.scenePosition
                node.eulerAngles.y = Float(placement.rotation) * .pi / 180.0
                node.name = "placed_piece"
                editorRootNode.addChildNode(node)
                placedNodes.append(node)
            }

        case .delete(let placement):
            if let index = pieces.firstIndex(where: {
                $0.position.x == placement.position.x && $0.position.z == placement.position.z
                && $0.model == placement.model
            }) {
                placedNodes[index].removeFromParentNode()
                placedNodes.remove(at: index)
                pieces.remove(at: index)
            }

        case .rotate(let index, _, let newRotation):
            guard index < pieces.count else { return }
            let piece = pieces[index]
            pieces[index] = PiecePlacement(
                model: piece.model, x: piece.position.x,
                z: piece.position.z, rotation: newRotation
            )
            placedNodes[index].eulerAngles.y = Float(newRotation) * .pi / 180.0

        case .setBall(_, let newPos):
            ballStartPosition = newPos
            ballMarkerNode?.position = SCNVector3(Float(newPos.x), 0.08, Float(newPos.z))

        case .setHole(_, let newPos):
            holeGridPosition = newPos
            holeMarkerNode?.position = SCNVector3(Float(newPos.x), 0.01, Float(newPos.z))
        }
    }

    func selectPreviousPiece() {
        guard let prev = lastUsedPieceModel else { return }
        selectPieceToPlace(prev)
    }

    // MARK: - Thumbnails

    func thumbnail(for modelName: String) -> UIImage {
        if let cached = thumbnailCache[modelName] {
            return cached
        }
        let image = renderThumbnail(for: modelName)
        thumbnailCache[modelName] = image
        return image
    }

    private func renderThumbnail(for modelName: String) -> UIImage {
        let scene = SCNScene()
        scene.background.contents = UIColor.clear

        guard let piece = AssetCatalog.shared.loadPiece(named: modelName) else {
            return placeholderThumbnail()
        }

        let (minBound, maxBound) = piece.boundingBox
        let cx = (minBound.x + maxBound.x) / 2
        let cy = (minBound.y + maxBound.y) / 2
        let cz = (minBound.z + maxBound.z) / 2
        piece.position = SCNVector3(-cx, -cy, -cz)
        scene.rootNode.addChildNode(piece)

        let width = maxBound.x - minBound.x
        let height = maxBound.y - minBound.y
        let depth = maxBound.z - minBound.z
        let maxExtent = max(width, max(height, depth))

        let cam = SCNCamera()
        cam.usesOrthographicProjection = true
        cam.orthographicScale = Double(maxExtent) * 0.75

        let camNode = SCNNode()
        camNode.camera = cam
        camNode.position = SCNVector3(2, 2, 2)
        camNode.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(camNode)

        let dirLight = SCNNode()
        dirLight.light = SCNLight()
        dirLight.light?.type = .directional
        dirLight.light?.intensity = 1000
        dirLight.eulerAngles = SCNVector3(-Float.pi / 3, Float.pi / 4, 0)
        scene.rootNode.addChildNode(dirLight)

        let ambLight = SCNNode()
        ambLight.light = SCNLight()
        ambLight.light?.type = .ambient
        ambLight.light?.intensity = 500
        scene.rootNode.addChildNode(ambLight)

        guard let device = MTLCreateSystemDefaultDevice() else { return placeholderThumbnail() }
        let renderer = SCNRenderer(device: device, options: nil)
        renderer.scene = scene
        renderer.pointOfView = camNode

        return renderer.snapshot(atTime: 0, with: CGSize(width: 120, height: 120),
                                 antialiasingMode: .multisampling2X)
    }

    private func placeholderThumbnail() -> UIImage {
        let size = CGSize(width: 120, height: 120)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        UIColor.darkGray.setFill()
        UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 8).fill()
        let image = UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
        UIGraphicsEndImageContext()
        return image
    }

    // MARK: - Serialization

    func toCourseDefinition() -> CourseDefinition {
        CourseDefinition(
            name: courseName,
            par: par,
            pieces: pieces,
            ballStart: ballStartPosition,
            holePosition: holeGridPosition
        )
    }

    // MARK: - Load

    func loadCourse(_ definition: CourseDefinition) {
        clearAll()

        courseName = definition.name
        par = definition.par
        ballStartPosition = definition.ballStart
        holeGridPosition = definition.holePosition

        for piece in definition.pieces {
            pieces.append(piece)
            if let node = AssetCatalog.shared.loadPiece(named: piece.model) {
                node.position = piece.position.scenePosition
                node.eulerAngles.y = Float(piece.rotation) * .pi / 180.0
                node.name = "placed_piece"
                editorRootNode.addChildNode(node)
                placedNodes.append(node)
            }
        }

        ballMarkerNode?.position = SCNVector3(
            Float(ballStartPosition.x), 0.08, Float(ballStartPosition.z)
        )
        holeMarkerNode?.position = SCNVector3(
            Float(holeGridPosition.x), 0.01, Float(holeGridPosition.z)
        )
    }

    // MARK: - Cleanup

    func clearAll() {
        for node in placedNodes {
            node.removeFromParentNode()
        }
        placedNodes.removeAll()
        pieces.removeAll()
        ghostNode?.removeFromParentNode()
        ghostNode = nil
        selectedPieceIndex = nil
        selectedPieceModel = nil
        ghostRotation = 0
        selectionHighlightNode?.isHidden = true
        undoStack.removeAll()
        redoStack.removeAll()
        lastUsedPieceModel = nil
        updateUndoRedoState()
    }
}
