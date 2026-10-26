import SwiftUI
import RealityKit
import ARKit

struct ARViewContainer: UIViewRepresentable {
    @Binding var isScanning: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> ARView {

        let arView = ARView(frame: .zero)

        let configuration = ARWorldTrackingConfiguration()

        guard ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) else {
            print("❌ LiDAR scene reconstruction is not available.")
            return arView
        }

        // MARK: - LiDAR Mesh Reconstruction

        // Use the raw mesh rather than mesh classification.
        // This is more appropriate for analysing the actual
        // surface shape of the car.
        configuration.sceneReconstruction = .mesh

        // Automatically improve environmental lighting.
        configuration.environmentTexturing = .automatic

        // MARK: - Higher Camera Capture Rate

        let supportedFormats =
            ARWorldTrackingConfiguration.supportedVideoFormats

        // Prefer 60 FPS formats.
        let highFrameRateFormats =
            supportedFormats.filter {
                $0.framesPerSecond >= 60
            }

        if let bestFormat =
            highFrameRateFormats.max(
                by: {
                    ($0.imageResolution.width *
                     $0.imageResolution.height)
                    <
                    ($1.imageResolution.width *
                     $1.imageResolution.height)
                }
            ) {

            configuration.videoFormat = bestFormat

            print("✅ High-rate camera format selected")
            print(
                "Resolution: \(bestFormat.imageResolution.width)x\(bestFormat.imageResolution.height)"
            )
            print(
                "FPS: \(bestFormat.framesPerSecond)"
            )

        } else {

            print("⚠️ No 60 FPS ARKit format available.")
        }

        // MARK: - Session

        arView.session.delegate = context.coordinator

        context.coordinator.isScanning = isScanning

        arView.session.run(
            configuration,
            options: [
                .resetTracking,
                .removeExistingAnchors
            ]
        )

        return arView
    }

    func updateUIView(
        _ uiView: ARView,
        context: Context
    ) {

        context.coordinator.isScanning = isScanning
    }

    static func dismantleUIView(
        _ uiView: ARView,
        coordinator: Coordinator
    ) {

        uiView.session.pause()
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, ARSessionDelegate {

        var isScanning = false

        // MARK: Mesh Added

        func session(
            _ session: ARSession,
            didAdd anchors: [ARAnchor]
        ) {

            guard isScanning else {
                return
            }

            for anchor in anchors {

                if let meshAnchor =
                    anchor as? ARMeshAnchor {

                    ScanManager.shared
                        .addMeshAnchor(meshAnchor)
                }
            }
        }

        // MARK: Mesh Updated

        func session(
            _ session: ARSession,
            didUpdate anchors: [ARAnchor]
        ) {

            guard isScanning else {
                return
            }

            for anchor in anchors {

                if let meshAnchor =
                    anchor as? ARMeshAnchor {

                    ScanManager.shared
                        .updateMeshAnchor(meshAnchor)
                }
            }
        }

        // MARK: Mesh Removed

        func session(
            _ session: ARSession,
            didRemove anchors: [ARAnchor]
        ) {

            guard isScanning else {
                return
            }

            for anchor in anchors {

                if let meshAnchor =
                    anchor as? ARMeshAnchor {

                    ScanManager.shared
                        .removeMeshAnchor(meshAnchor)
                }
            }
        }
    }
}
