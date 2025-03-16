#if os(visionOS)

import Foundation
import SwiftUI
import RealityKit
import ARKit

struct CalibrateView: View {
    static let spaceID = "CALIBRATE"

    enum Phase {
        case waiting
        case calibrated
    }
    
    @Environment(\.dismissImmersiveSpace) var dismissImmersiveSpace

    @State var phase: Phase = .waiting
    @State var viewModel = CalibrateViewModel()
    let cubeVM: CubeViewModel

    var body: some View {
        RealityView { content in
            viewModel.centerNode.transform.translation = [0, 0.7, -0.35]
            content.add(viewModel.centerNode)

            Task {
                try? await Task.sleep(for: .seconds(3))
                cubeVM.calibrate()
                phase = .calibrated
                viewModel.centerNode.components.set(OpacityComponent(opacity: 0.7))
                try? await Task.sleep(for: .seconds(5))
                await dismissImmersiveSpace()
            }
        } update: { content in
            guard phase == .calibrated else { return }

            guard let leftMiddle = viewModel.leftHand?.transform(for: .middleFingerTip),
                  let leftThumb = viewModel.leftHand?.transform(for: .thumbTip),
                  let rightMiddle = viewModel.rightHand?.transform(for: .middleFingerTip),
                  let rightThumb = viewModel.rightHand?.transform(for: .thumbTip)
                  else { return }

            let allJoints = [leftMiddle, leftThumb, rightMiddle, rightThumb]
            let translation = allJoints.map(\.translation).reduce(.zero, +) / Float(allJoints.count)

            viewModel.centerNode.transform = Transform(translation: translation)
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
    let cubeNode: Entity

    init() {
        let node = Entity()

        cubeNode = CubeEntity(cubeVM: CubeViewModelManager.shared.current, trackOrientation: false)
        node.addChild(cubeNode)
        node.components.set(OpacityComponent(opacity: 0.3))

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
