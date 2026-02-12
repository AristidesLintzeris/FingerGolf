import SceneKit

class AssetCatalog {

    static let shared = AssetCatalog()

    private var nodeCache: [String: SCNNode] = [:]
    private var sharedMaterial: SCNMaterial?

    private init() {
        loadSharedMaterial()
    }

    // MARK: - Material

    private func loadSharedMaterial() {
        let material = SCNMaterial()
        if let image = UIImage(named: "colormap") ?? loadColormapFromBundle() {
            material.diffuse.contents = image
        }
        material.lightingModel = .blinn
        material.isDoubleSided = false
        sharedMaterial = material
    }

    private func loadColormapFromBundle() -> UIImage? {
        guard let url = Bundle.main.url(
            forResource: "colormap",
            withExtension: "png",
            subdirectory: "art.scnassets/Textures"
        ) else { return nil }
        return UIImage(contentsOfFile: url.path)
    }

    // MARK: - Model Loading

    func loadPiece(named name: String) -> SCNNode? {
        if let cached = nodeCache[name] {
            return cached.clone()
        }

        // Load via SCNScene(named:) which is the standard .scnassets API
        guard let scene = SCNScene(named: "art.scnassets/\(name).obj") else {
            print("AssetCatalog: Missing model '\(name)'")
            return nil
        }

        let containerNode = SCNNode()
        containerNode.name = name

        for child in scene.rootNode.childNodes {
            applySharedMaterial(to: child)
            containerNode.addChildNode(child.clone())
        }

        nodeCache[name] = containerNode
        return containerNode.clone()
    }

    private func applySharedMaterial(to node: SCNNode) {
        if let geometry = node.geometry, let material = sharedMaterial {
            geometry.materials = [material]
        }
        for child in node.childNodes {
            applySharedMaterial(to: child)
        }
    }

    // MARK: - Preloading

    func preloadCommonAssets() {
        let commonModels = [
            "straight", "corner", "end",
            "hole-open", "hole-round", "hole-square",
            "ball-red", "ball-blue", "ball-green",
            "club-red", "club-blue", "club-green",
            "flag-red", "flag-blue", "flag-green",
            "ramp", "ramp-low", "ramp-medium", "ramp-high",
            "wall-left", "wall-right",
            "bump", "obstacle-block", "obstacle-diamond", "obstacle-triangle",
            "tunnel-narrow", "tunnel-wide",
            "split", "split-t",
            "inner-corner", "round-corner-a",
            "structure-windmill", "windmill"
        ]
        for model in commonModels {
            _ = loadPiece(named: model)
        }
    }

    func clearCache() {
        nodeCache.removeAll()
    }
}
