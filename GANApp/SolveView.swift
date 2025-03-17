#if os(visionOS)

import Foundation
import SwiftUI
import RealityKit
import ARKit
import CubeKit

struct SolveView: View {
    static let spaceID = "SOLVE"

    @State var viewModel = SolveViewModel()
    let cubeVM: CubeViewModel

    var body: some View {
        RealityView { content in
            content.add(viewModel.centerNode)
        } update: { content in
            guard let leftMiddle = viewModel.leftHand?.transform(for: .middleFingerTip),
                  let leftThumb = viewModel.leftHand?.transform(for: .thumbTip),
                  let rightMiddle = viewModel.rightHand?.transform(for: .middleFingerTip),
                  let rightThumb = viewModel.rightHand?.transform(for: .thumbTip)
                  else { return }

            let allJoints = [leftMiddle, leftThumb, rightMiddle, rightThumb]
            let translation = allJoints.map(\.translation).reduce(.zero, +) / Float(allJoints.count)

            viewModel.centerNode.transform.translation = translation
            viewModel.cubeNode.transform.rotation = cubeVM.orientation.map {
                simd_quatf(vector: simd_float4($0.vector))
            } ?? simd_quatf()
        }
        .task {
            do {
                try await viewModel.runSolve(cubeVM: cubeVM)
            } catch {
                print("ERROR: \(error)")
            }
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

@Observable @MainActor final class SolveViewModel {
    private(set) var steps: SolveTracker? {
        didSet { updateStep() }
    }

    let centerNode: Entity
    let cubeNode: CubeEntity

    init() {
        let node = Entity()

        cubeNode = CubeEntity()
        node.addChild(cubeNode)
        node.components.set(OpacityComponent(opacity: 0.7))

        centerNode = node
    }

    var leftHand: HandAnchor?
    var rightHand: HandAnchor?

    func runSolve(cubeVM: CubeViewModel) async throws {
        var state = cubeVM.rsCube

        cubeNode.setCube(state)

        var steps = try await SolveTracker(moves: state.solution().values)
        self.steps = steps

        print(steps)

        if let nextStep = steps.moves.first {
            cubeNode.setCube(state.applying([nextStep]), animation: .init(move: nextStep, duration: 0.5))
        }

        for await move in cubeVM.cube.moves.values where !steps.moves.isEmpty {
            state.apply(move)
            cubeNode.setCube(state)
            steps.apply(move)
            self.steps = steps
            if let nextStep = steps.moves.first {
                cubeNode.setCube(state.applying([nextStep]), animation: .init(move: nextStep, duration: 0.5))
            }
            print(steps)
        }

        print("DONE", steps)
    }

    private func updateStep() {
        guard let step = steps?.moves.first else { return }
        print("STEP: \(step)")
    }

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
