#if os(visionOS)

import Foundation
import SwiftUI
import RealityKit
import ARKit

struct SolveView: View {
    static let spaceID = "SOLVE"

    enum Phase {
        case waiting
        case started(Date)
        case solved(TimeInterval)
    }

    @State var phase: Phase = .waiting
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
            let scale = leftMiddle.scale

            let rotation = simd_quatf(from: .init(x: 0, y: 0, z: 0), to: .init(x: 0, y: 1, z: 0))

            let translation = allJoints.map(\.translation).reduce(.zero, +) / Float(allJoints.count)

            viewModel.centerNode.transform = Transform(scale: scale, rotation: rotation, translation: translation)
            viewModel.cubeNode.transform.rotation = cubeVM.orientation.map {
                simd_quatf(vector: simd_float4($0.vector))
            } ?? simd_quatf()

            let time: TimeInterval = switch phase {
            case .waiting:
                (0)
            case .started(let date):
                (Date().timeIntervalSince(date))
            case .solved(let timeInterval):
                timeInterval
            }
            let text = time.formatted(.number.precision(.fractionLength(3...3)))
            var attrText = AttributedString(text)
            attrText.uiKit.font = UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)
//            let paragraphStyle = NSMutableParagraphStyle()
//            paragraphStyle.alignment = .center
//            attrText.setAttributes(AttributeContainer([
//                .paragraphStyle: paragraphStyle
//            ]))
//            var textOptions = MeshResource.GenerateTextOptions()
//            textOptions.containerFrame = CGRect(x: 0, y: 0, width: 0.0575 * 3 * 72, height: 0.0575 * 72)
            let textMesh = try! MeshResource(
                extruding: attrText,
                textOptions: MeshResource.GenerateTextOptions(),
                extrusionOptions: MeshResource.ShapeExtrusionOptions()
            )
            viewModel.textModel.model!.mesh = textMesh
            viewModel.textModel.position = (textMesh.bounds.min - textMesh.bounds.center) * [1, 1, 0]
        }
        .task {
            do {
                try await viewModel.runTracking()
            } catch {
                print("ERROR: \(error)")
            }
        }
        .onChange(of: cubeVM.rsCube) { old, new in
            switch phase {
            case .solved:
                break
            case .waiting:
                phase = .started(Date())
            case .started(let start):
                if new == .solved {
                    let end = Date()
                    phase = .solved(end.timeIntervalSince(start))
                }
            }
        }
    }
}

extension HandAnchor {
    func transform(for jointName: HandSkeleton.JointName) -> Transform? {
        guard let handSkeleton else { return nil }
        let joint = handSkeleton.joint(jointName)
        guard joint.isTracked else { return nil }
        let matrix = originFromAnchorTransform * joint.anchorFromJointTransform
        return Transform(matrix: matrix)
    }
}

@Observable @MainActor final class SolveViewModel {
    let centerNode: Entity
    let textModel: ModelEntity
    let cubeNode: ModelEntity

    init() {
        let node = Entity()

        let material = SimpleMaterial(color: .white, isMetallic: false)
        let mesh = MeshResource.generateBox(width: 0.0575 * 3, height: 0.0575, depth: 0.0575 / 4)
        let textBG = ModelEntity(mesh: mesh, materials: [material])
        textBG.position.y += 0.12
        node.addChild(textBG)

        let cubeMaterial = SimpleMaterial(color: .init(white: 1, alpha: 0.1), isMetallic: false)
        let cubeMesh = MeshResource.generateBox(size: 0.0575)
        cubeNode = ModelEntity(mesh: cubeMesh, materials: [cubeMaterial])
        cubeNode.position.y += 0.12
        cubeNode.position.x -= 0.0575 * 3
        node.addChild(cubeNode)

        let textMaterial = SimpleMaterial(color: .black, isMetallic: false)
        let textMesh = MeshResource.generateBox(size: 1)
        textModel = ModelEntity(mesh: textMesh, materials: [textMaterial])
        let textNode = Entity()
        textNode.addChild(textModel)
        textNode.position.z += 0.0575 / 4
        textNode.scale *= 0.2
        textBG.addChild(textNode)

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
