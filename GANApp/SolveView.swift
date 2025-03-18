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
            viewModel.centerNode.transform.rotation = cubeVM.orientation.map {
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
    let face: ModelEntity

    init() {
        let node = Entity()

        let turnPath = Path {
            $0.addArc(
                center: .zero,
                radius: 0.0575 * 1.1,
                startAngle: .degrees(0),
                endAngle: .degrees(90),
                clockwise: true
            )
        }.strokedPath(.init(lineWidth: 0.0575 / 4, dash: [0.0575 / 8, 0.0575 / 8]))
        var options = MeshResource.ShapeExtrusionOptions()
        options.extrusionMethod = .linear(depth: 0.0575 / 8)
        let faceMesh = try! MeshResource(extruding: turnPath, extrusionOptions: options)
        face = ModelEntity(mesh: faceMesh, materials: [
            SimpleMaterial(color: .white, isMetallic: false)
        ])
        node.addChild(face)
        node.components.set(OpacityComponent(opacity: 0.3))

        let cubeMesh = MeshResource.generateBox(size: 0.0575)
        let cube = ModelEntity(mesh: cubeMesh, materials: [
            OcclusionMaterial()
        ])
        node.addChild(cube)

        centerNode = node
    }

    var leftHand: HandAnchor?
    var rightHand: HandAnchor?

    func playMove(_ move: Move?) {
        face.stopAllAnimations()
        guard let move else {
            face.transform = .identity
            face.components.set(OpacityComponent(opacity: 0))
            return
        }

        face.components.set(OpacityComponent(opacity: 1))

        let forwardFace: Face = switch move.face {
        case .top: .front
        case .right: .bottom
        case .front: .bottom
        case .bottom: .back
        case .left: .bottom
        case .back: .bottom
        }

        let transform = Transform(
            rotation: .init(Rotation3D(forward: Vector3D(forwardFace.offset), up: Vector3D(move.face.offset)) * Rotation3D(angle: .degrees(90), axis: .x)),
            translation: move.face.offset * 0.0575 / 3
        )
        let animation = OrbitAnimation(
            duration: 4,
            axis: move.face.offset,
            startTransform: transform,
            spinClockwise: move.magnitude != .counterClockwiseQuarterTurn,
            orientToPath: true,
            rotationCount: 1,
            bindTarget: .transform
        )
        face.transform = transform
        face.playAnimation(try! AnimationResource.generate(with: animation).repeat())
    }

    func runSolve(cubeVM: CubeViewModel) async throws {
        var state = cubeVM.rsCube

        var steps = try await SolveTracker(moves: state.solution().values)
        self.steps = steps

        for await move in cubeVM.cube.moves.values where !steps.moves.isEmpty {
            state.apply(move)
            steps.apply(move)
            self.steps = steps
            print(steps)
        }

        print("DONE", steps)
    }

    private func updateStep() {
        playMove(steps?.moves.first)
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
