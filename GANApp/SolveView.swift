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
    let indicator: Entity

    init() {
        let node = Entity()
        node.transform.scale = SIMD3(repeating: 0.0575)

        indicator = Entity()
        node.addChild(indicator)

        let turnRadius = 1.1
        let turnPath = Path {
            $0.addArc(
                center: .zero,
                radius: turnRadius,
                startAngle: .degrees(0),
                endAngle: .degrees(105),
                clockwise: true
            )
        }
        .strokedPath(.init(
            lineWidth: 0.25,
            dash: [0.25, 0.25]
        ))
        var options = MeshResource.ShapeExtrusionOptions()
        options.extrusionMethod = .linear(depth: 0.25)
        let turnMesh = try! MeshResource(extruding: turnPath, extrusionOptions: options)
        let turn = ModelEntity(mesh: turnMesh, materials: [
            SimpleMaterial(color: .white, isMetallic: false)
        ])
        turn.components.set(OpacityComponent(opacity: 0.3))
        indicator.addChild(turn)

        let coneMesh = MeshResource.generateCone(height: 0.5, radius: 0.25)
        let cone = ModelEntity(mesh: coneMesh, materials: [
            SimpleMaterial(color: .white, isMetallic: false)
        ])
        cone.transform.rotation = .init(Rotation3D(angle: .degrees(-90), axis: .z))
        cone.transform.translation = [0, Float(turnRadius), 0]
        turn.addChild(cone)

        let animation = OrbitAnimation(
            duration: 4,
            axis: [0, 0, 1],
            orientToPath: true,
            bindTarget: .transform
        )
        turn.playAnimation(try! .generate(with: animation).repeat())

        let cubeMesh = MeshResource.generateBox(size: 1.0)
        let cube = ModelEntity(mesh: cubeMesh, materials: [
            OcclusionMaterial()
        ])
        node.addChild(cube)

        centerNode = node
    }

    var leftHand: HandAnchor?
    var rightHand: HandAnchor?

    func playMove(_ move: Move?) {
        guard let move else {
            indicator.isEnabled = false
            return
        }

        indicator.isEnabled = true

        let forwardFace: Face = switch move.face {
        case .top: .front
        case .bottom: .back
        case .right, .front, .left, .back: .bottom
        }
        let isCCW = move.magnitude == .counterClockwiseQuarterTurn

        indicator.transform = Transform(
            rotation: .init(Rotation3D(
                forward: Vector3D(forwardFace.offset),
                up: Vector3D(move.face.offset)
            ) * Rotation3D(
                angle: .degrees(isCCW ? 90 : -90),
                axis: .x
            )),
            translation: move.face.offset / 3
        )
    }

    func runSolve(cubeVM: CubeViewModel) async throws {
        var steps = try await SolveTracker(moves: cubeVM.rsCube.solution().values)
        self.steps = steps
        for await move in cubeVM.cube.moves.values {
            steps.apply(move)
            self.steps = steps
        }
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
