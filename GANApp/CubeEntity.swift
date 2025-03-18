import RealityKit
import CubeKit
import Spatial

final class CubeEntity: Entity {
    private static let realCubeSize: Float = 0.0575
    private static let cubeSize: Float = {
        #if os(visionOS)
        realCubeSize
        #else
        1
        #endif
    }()
    private static let cubeeSize: Float = cubeSize / 3
    private static let relativeCornerRadius: Float = 0.05
    private static let relativePadding: Float = 1.0

    private let centerEntities: [ModelEntity]
    private let cornerEntities: [ModelEntity]
    private let edgeEntities: [ModelEntity]

    private var allEntities: [ModelEntity] {
        centerEntities + cornerEntities + edgeEntities
    }

    convenience init(cubeVM: CubeViewModel?, trackOrientation: Bool = true) {
        self.init()
        if let cubeVM {
            self.trackConfiguration(cubeVM: cubeVM)
            if trackOrientation {
                self.trackOrientation(cubeVM: cubeVM)
            }
        }
    }

    required init() {
        let cubeeMesh = MeshResource.generateBox(
            width: Self.cubeeSize,
            height: Self.cubeeSize,
            depth: Self.cubeeSize,
            cornerRadius: Self.cubeeSize * Self.relativeCornerRadius,
            splitFaces: true
        )

        // the order of face materials expected by the box mesh resource
        // with splitFaces=true
        let faceOrder: [Face] = [.front, .top, .back, .bottom, .right, .left]

        centerEntities = Face.allCases.map { loc in
            let colors = faceOrder.map { loc == $0 ? $0.color : .black }
            let materials = colors.map { SimpleMaterial(color: $0, roughness: 1.0, isMetallic: false) }
            let entity = ModelEntity(mesh: cubeeMesh, materials: materials)
            entity.transform.translation = loc.offset * Self.cubeeSize * Self.relativePadding
            return entity
        }

        cornerEntities = CornerLocation.allCases.map { loc in
            let colors: [SimpleMaterial.Color] = faceOrder.map { loc.faces.contains($0) ? $0.color : .black }
            let materials = colors.map { SimpleMaterial(color: $0, roughness: 1.0, isMetallic: false) }
            return ModelEntity(mesh: cubeeMesh, materials: materials)
        }

        edgeEntities = EdgeLocation.allCases.map { loc in
            let colors: [SimpleMaterial.Color] = faceOrder.map { loc.faces.contains($0) ? $0.color : .black }
            let materials = colors.map { SimpleMaterial(color: $0, roughness: 1.0, isMetallic: false) }
            return ModelEntity(mesh: cubeeMesh, materials: materials)
        }

        super.init()

        for entity in allEntities {
            self.addChild(entity)
        }

        self.setCube(.solved)
    }

    private func trackOrientation(cubeVM: CubeViewModel) {
        observeChanges { [weak self] in
            guard let self else { return }

            self.orientation = if let orientation = cubeVM.orientation {
                simd_quatf(vector: SIMD4(orientation.vector))
            } else {
                simd_quatf(.identity)
            }
        }
    }

    private func trackConfiguration(cubeVM: CubeViewModel) {
        observeChanges { [weak self] in
            guard let self else { return }
            setCube(cubeVM.rsCube, move: cubeVM.lastMove)
        }
    }

    struct Animation {
        var move: Move
        var duration: Double = 0.1
    }

    func setCube(_ cube: Cube, move: Move?) {
        self.setCube(cube, animation: move.map { Animation(move: $0) })
    }

    private var lastAnimations: [AnimationPlaybackController] = []

    func setCube(_ cube: Cube, animation: Animation? = nil) {
        for animation in lastAnimations {
            // complete current animations
            animation.time = animation.duration
        }
        lastAnimations.removeAll()

        let move = animation?.move

        if let move {
            // when animating, always start from the state right before this move
            self.setCube(cube.applying([move.inverse]))
        }

        var animations: [AnimationPlaybackController] = []
        defer { lastAnimations = animations }
        func animate(_ entity: Entity, from start: Transform) {
            guard let animation else { return }
            let move = animation.move
            let orbit = OrbitAnimation(
                duration: animation.duration,
                axis: move.face.offset,
                startTransform: start,
                spinClockwise: move.magnitude != .counterClockwiseQuarterTurn,
                orientToPath: true,
                rotationCount: move.magnitude == .halfTurn ? 0.5 : 0.25,
                bindTarget: .transform
            )
            let resource = try! AnimationResource.generate(with: orbit)
            animations.append(entity.playAnimation(resource))
        }

        if let move {
            let center = centerEntities[move.face.rawValue]
            center.transform.rotation = .init(.identity)
            animate(center, from: center.transform)
        }

        // the location that the corner will be in
        for cornerDrawLocation in CornerLocation.allCases {
            let corner = cube.corners[cornerDrawLocation]
            // the corner that will be in this location
            let cornerSourceLocation = corner.location
            let cornerEntity = cornerEntities[cornerSourceLocation.rawValue]

            let startTransform = cornerEntity.transform

            cornerEntity.transform.translation = cornerDrawLocation.offset * Self.cubeeSize * Self.relativePadding

            let sourceRotation = cornerSourceLocation.referenceRotation
            let drawRotation = cornerDrawLocation.referenceRotation
            let degrees: Double = switch corner.orientation {
            case .correct: 0
            case .rotatedClockwise: -120
            case .rotatedCounterClockwise: 120
            }
            let orient = Rotation3D(angle: .degrees(degrees), axis: .xyz)
            // inverse of sourceRotation => rotate corner to top-right-front
            // orient => rotate around top-right-front axis as needed
            // drawRotation => rotate corner to match drawn position
            cornerEntity.transform.rotation = simd_quatf(drawRotation * orient * sourceRotation.inverse)

            if let move, cornerDrawLocation.faces.contains(move.face) {
                animate(cornerEntity, from: startTransform)
            }
        }

        for edgeDrawLocation in EdgeLocation.allCases {
            let edge = cube.edges[edgeDrawLocation]
            let edgeSourceLocation = edge.location
            let edgeEntity = edgeEntities[edgeSourceLocation.rawValue]

            let startTransform = edgeEntity.transform

            edgeEntity.transform.translation = edgeDrawLocation.offset * Self.cubeeSize * Self.relativePadding

            let sourceRotation = edgeSourceLocation.referenceRotation
            let drawRotation = edgeDrawLocation.referenceRotation
            let degrees: Double = edge.orientation == .flipped ? 180 : 0
            let orient = Rotation3D(angle: .degrees(degrees), axis: .yz)
            edgeEntity.transform.rotation = simd_quatf(drawRotation * orient * sourceRotation.inverse)

            if let move, edgeDrawLocation.faces.contains(move.face) {
                animate(edgeEntity, from: startTransform)
            }
        }
    }
}

extension CornerLocation {
    fileprivate var offset: SIMD3<Float> {
        faces.map(\.offset).reduce(.zero, +)
    }

    // the transform required to rotate the top-right-front corner to this corner
    // when in the "correct" orientation
    fileprivate var referenceRotation: Rotation3D {
        Rotation3D(
            forward: .init(faces[2].offset),
            up: .init(faces[0].offset)
        )
    }
}

extension EdgeLocation {
    fileprivate var offset: SIMD3<Float> {
        faces.map(\.offset).reduce(.zero, +)
    }

    // the transform required to rotate the top-front edge to this edge
    // when in the "correct" orientation
    fileprivate var referenceRotation: Rotation3D {
        Rotation3D(
            forward: .init(faces[1].offset),
            up: .init(faces[0].offset)
        )
    }
}

extension Face {
    var offset: SIMD3<Float> {
        switch self {
        case .top: [0, 1, 0]
        case .bottom: [0, -1, 0]
        case .left: [-1, 0, 0]
        case .right: [1, 0, 0]
        case .front: [0, 0, 1]
        case .back: [0, 0, -1]
        }
    }

    // these colors are aligned with the GAN face definitions.
    // eg, when GAN sends us a 'U' it means the white face.
    var color: SimpleMaterial.Color {
        switch self {
        case .top: .white
        case .bottom: .yellow
        case .left: .orange
        case .right: .red
        case .front: .green
        case .back: .blue
        }
    }
}
