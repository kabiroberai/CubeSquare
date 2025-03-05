#if os(visionOS)

import Foundation
import SwiftUI
import RealityKit
import ARKit

struct CalibrateView: View {
    static let spaceID = "CALIBRATE"

    enum Phase {
        case waiting
        case started(Date)
        case solved(TimeInterval)
    }

    @State var phase: Phase = .waiting
    @State var viewModel = CalibrateViewModel()
    let cubeVM: CubeViewModel

    var body: some View {
        RealityView { content in
            content.add(CubeEntity())
        } update: { content in
            guard let leftMiddle = viewModel.leftHand?.transform(for: .middleFingerTip),
                  let leftThumb = viewModel.leftHand?.transform(for: .thumbTip),
                  let rightMiddle = viewModel.rightHand?.transform(for: .middleFingerTip),
                  let rightThumb = viewModel.rightHand?.transform(for: .thumbTip)
                  else { return }

            let scale = SIMD3<Float>(repeating: 1)
            let rotation = simd_quatf(from: .init(x: 0, y: 0, z: 0), to: .init(x: 0, y: 1, z: 0))

            let allJoints = [leftMiddle, leftThumb, rightMiddle, rightThumb]
            let translation = allJoints.map(\.translation).reduce(.zero, +) / Float(allJoints.count)

            viewModel.centerNode.transform = Transform(scale: scale, rotation: rotation, translation: translation)
            viewModel.cubeNode.transform.rotation = cubeVM.orientation.map {
                simd_quatf(vector: simd_float4($0.vector))
            } ?? simd_quatf()
        }
        .task {
            do {
                try await viewModel.runTracking()
            } catch {
                print("ERROR: \(error)")
            }
        }
    }
}

@Observable @MainActor final class CalibrateViewModel {
    let centerNode: Entity
    let cubeNode: ModelEntity

    init() {
        let node = Entity()

        let cubeMaterial = SimpleMaterial(color: .init(white: 1, alpha: 0.1), isMetallic: false)
        let cubeMesh = MeshResource.generateBox(size: 0.0575)
        cubeNode = ModelEntity(mesh: cubeMesh, materials: [cubeMaterial])
        cubeNode.position.y += 0.12
        cubeNode.position.x -= 0.0575 * 3
        node.addChild(cubeNode)

        centerNode = node
    }

    var leftHand: HandAnchor?
    var rightHand: HandAnchor?

    func runTracking() async throws {
        let session = ARKitSession()
        let handTrackingProvider = HandTrackingProvider()

        try await session.run([handTrackingProvider])

        for await update in handTrackingProvider.anchorUpdates {
            switch update.anchor.chirality {
            case .left:
                self.leftHand = update.anchor
            case .right:
                self.rightHand = update.anchor
            }
        }
    }
}

#endif
