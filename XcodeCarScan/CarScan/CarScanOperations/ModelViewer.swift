import SwiftUI
import SceneKit

struct ModelViewer: View {
    let modelURL: URL

    var body: some View {
        ModelSceneView(modelURL: modelURL)
            .navigationTitle("3D Car Model")
            .navigationBarTitleDisplayMode(.inline)
            .ignoresSafeArea(edges: .bottom)
    }
}

struct ModelSceneView: UIViewRepresentable {
    let modelURL: URL

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = UIColor.systemBackground
        view.allowsCameraControl = true
        view.autoenablesDefaultLighting = true
        view.antialiasingMode = .multisampling4X
        view.preferredFramesPerSecond = 60

        do {
            let scene = try SCNScene(url: modelURL, options: nil)
            view.scene = scene
            view.defaultCameraController.automaticTarget = true
            view.defaultCameraController.frameNodes(scene.rootNode.childNodes)
        } catch {
            print("Could not load saved model: \(error)")
        }

        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {}
}