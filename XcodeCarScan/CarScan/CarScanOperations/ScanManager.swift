import Foundation
import Combine
import ARKit
import SceneKit
import UIKit

final class ScanManager: ObservableObject {
    static let shared = ScanManager()
    private init() {}

    @Published private(set) var isExporting = false
    @Published private(set) var savedModelURL: URL?
    @Published private(set) var meshCount = 0
    @Published private(set) var errorMessage: String?

    private let lock = NSLock()
    private var meshAnchors: [UUID: ARMeshAnchor] = [:]

    func startNewScan() {
        lock.lock()
        meshAnchors.removeAll()
        lock.unlock()

        DispatchQueue.main.async {
            self.meshCount = 0
            self.savedModelURL = nil
            self.errorMessage = nil
        }
    }

    func addMeshAnchor(_ anchor: ARMeshAnchor) {
        lock.lock()
        meshAnchors[anchor.identifier] = anchor
        let count = meshAnchors.count
        lock.unlock()

        DispatchQueue.main.async { self.meshCount = count }
    }

    func updateMeshAnchor(_ anchor: ARMeshAnchor) {
        lock.lock()
        meshAnchors[anchor.identifier] = anchor
        lock.unlock()
    }

    func removeMeshAnchor(_ anchor: ARMeshAnchor) {
        lock.lock()
        meshAnchors.removeValue(forKey: anchor.identifier)
        let count = meshAnchors.count
        lock.unlock()

        DispatchQueue.main.async { self.meshCount = count }
    }

    func exportScan(completion: @escaping (Result<URL, Error>) -> Void) {
        lock.lock()
        let anchors = Array(meshAnchors.values)
        lock.unlock()

        guard !anchors.isEmpty else {
            let error = NSError(
                domain: "CarScan",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "No LiDAR mesh was captured. Scan the car first."]
            )
            DispatchQueue.main.async {
                self.errorMessage = error.localizedDescription
                completion(.failure(error))
            }
            return
        }

        DispatchQueue.main.async {
            self.isExporting = true
            self.errorMessage = nil
        }

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let scene = try self.createScene(from: anchors)
                let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let url = documents.appendingPathComponent("ScannedCar.usdz")

                if FileManager.default.fileExists(atPath: url.path) {
                    try FileManager.default.removeItem(at: url)
                }

                guard scene.write(to: url, options: nil, delegate: nil, progressHandler: nil) else {
                    throw NSError(
                        domain: "CarScan",
                        code: 2,
                        userInfo: [NSLocalizedDescriptionKey: "SceneKit could not write the 3D model."]
                    )
                }

                DispatchQueue.main.async {
                    self.isExporting = false
                    self.savedModelURL = url
                    completion(.success(url))
                }
            } catch {
                DispatchQueue.main.async {
                    self.isExporting = false
                    self.errorMessage = error.localizedDescription
                    completion(.failure(error))
                }
            }
        }
    }

    private func createScene(from anchors: [ARMeshAnchor]) throws -> SCNScene {
        let scene = SCNScene()
        let root = SCNNode()
        root.name = "ScannedCar"
        scene.rootNode.addChildNode(root)

        for anchor in anchors {
            if let geometry = makeGeometry(from: anchor) {
                let node = SCNNode(geometry: geometry)
                node.transform = SCNMatrix4(anchor.transform)
                root.addChildNode(node)
            }
        }
        return scene
    }

    private func makeGeometry(from anchor: ARMeshAnchor) -> SCNGeometry? {
        let mesh = anchor.geometry
        guard mesh.vertices.count > 0, mesh.faces.count > 0 else { return nil }

        let vertexDataSize = mesh.vertices.stride * mesh.vertices.count
        let vertexPointer = mesh.vertices.buffer.contents().advanced(by: mesh.vertices.offset)
        let vertexData = Data(bytes: vertexPointer, count: vertexDataSize)

        let vertices = SCNGeometrySource(
            data: vertexData,
            semantic: .vertex,
            vectorCount: mesh.vertices.count,
            usesFloatComponents: true,
            componentsPerVector: 3,
            bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: 0,
            dataStride: mesh.vertices.stride
        )

        let normalDataSize = mesh.normals.stride * mesh.normals.count
        let normalPointer = mesh.normals.buffer.contents().advanced(by: mesh.normals.offset)
        let normalData = Data(bytes: normalPointer, count: normalDataSize)

        let normals = SCNGeometrySource(
            data: normalData,
            semantic: .normal,
            vectorCount: mesh.normals.count,
            usesFloatComponents: true,
            componentsPerVector: 3,
            bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: 0,
            dataStride: mesh.normals.stride
        )

        let indexCount = mesh.faces.count * mesh.faces.indexCountPerPrimitive
        let indexDataSize = indexCount * mesh.faces.bytesPerIndex
        let indexData = Data(bytes: mesh.faces.buffer.contents(), count: indexDataSize)

        let element = SCNGeometryElement(
            data: indexData,
            primitiveType: .triangles,
            primitiveCount: mesh.faces.count,
            bytesPerIndex: mesh.faces.bytesPerIndex
        )

        let geometry = SCNGeometry(sources: [vertices, normals], elements: [element])

        let material = SCNMaterial()
        material.diffuse.contents = UIColor.lightGray
        material.specular.contents = UIColor.white
        material.shininess = 20
        geometry.firstMaterial = material

        return geometry
    }
}
