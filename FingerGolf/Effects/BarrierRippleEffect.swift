import SceneKit

class BarrierRippleEffect {

    func triggerRipple(at contactPoint: SCNVector3, in scene: SCNScene) {
        let rippleNode = createRippleNode()
        rippleNode.position = SCNVector3(contactPoint.x, 0.1, contactPoint.z)
        scene.rootNode.addChildNode(rippleNode)

        // Animate: expand + fade out
        let expandScale = SCNAction.scale(to: 3.0, duration: 0.6)
        expandScale.timingMode = .easeOut

        let fadeOut = SCNAction.fadeOut(duration: 0.6)
        fadeOut.timingMode = .easeIn

        let group = SCNAction.group([expandScale, fadeOut])
        let remove = SCNAction.removeFromParentNode()

        rippleNode.runAction(SCNAction.sequence([group, remove]))
    }

    /// Flash ripple effects along all 4 barrier walls to visualize boundaries.
    func flashBoundaries(in scene: SCNScene, courseBounds: (min: SCNVector3, max: SCNVector3)) {
        let padding: Float = 0.1
        let (minB, maxB) = courseBounds
        let rippleCount = 3

        // North wall
        for i in 0..<rippleCount {
            let t = Float(i + 1) / Float(rippleCount + 1)
            let x = minB.x + (maxB.x - minB.x) * t
            triggerRipple(at: SCNVector3(x, 0.1, maxB.z + padding), in: scene)
        }
        // South wall
        for i in 0..<rippleCount {
            let t = Float(i + 1) / Float(rippleCount + 1)
            let x = minB.x + (maxB.x - minB.x) * t
            triggerRipple(at: SCNVector3(x, 0.1, minB.z - padding), in: scene)
        }
        // East wall
        for i in 0..<rippleCount {
            let t = Float(i + 1) / Float(rippleCount + 1)
            let z = minB.z + (maxB.z - minB.z) * t
            triggerRipple(at: SCNVector3(maxB.x + padding, 0.1, z), in: scene)
        }
        // West wall
        for i in 0..<rippleCount {
            let t = Float(i + 1) / Float(rippleCount + 1)
            let z = minB.z + (maxB.z - minB.z) * t
            triggerRipple(at: SCNVector3(minB.x - padding, 0.1, z), in: scene)
        }
    }

    private func createRippleNode() -> SCNNode {
        let ring = SCNTorus(ringRadius: 0.15, pipeRadius: 0.005)

        let material = SCNMaterial()
        material.diffuse.contents = UIColor(red: 0.7, green: 0.85, blue: 1.0, alpha: 0.6)
        material.transparency = 0.6
        material.isDoubleSided = true
        material.blendMode = .add
        material.writesToDepthBuffer = false
        ring.firstMaterial = material

        let node = SCNNode(geometry: ring)
        // Lay flat on the ground
        node.eulerAngles.x = .pi / 2
        node.scale = SCNVector3(0.3, 0.3, 0.3)
        node.opacity = 0.8

        return node
    }
}
