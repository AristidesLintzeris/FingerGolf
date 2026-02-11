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
