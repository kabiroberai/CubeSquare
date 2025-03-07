import CubeKit
import SwiftUI
import simd
import Spatial

struct ContentView: View {
    @State private var cubeVM: CubeViewModel?

    var body: some View {
        VStack {
            if let cubeVM {
                CubeView(cubeVM: cubeVM)
            } else {
                ProgressView("Searching for cubes")
            }
        }
        .padding()
        .task {
            let manager = GANManager()
            let potentialCube = await manager.cubes.values.first(where: { _ in true })!
            let cube = try! await potentialCube.connect()
            self.cubeVM = CubeViewModel(cube: cube)
        }
    }
}

@Observable
@MainActor
final class CubeViewModelManager {
    static let shared = CubeViewModelManager()

    fileprivate(set) var current: CubeViewModel?
}

@Observable
@MainActor
final class CubeViewModel {
    func makeCurrent() {
        CubeViewModelManager.shared.current = self
    }

    let cube: GANCube

    var batteryLevel: Int?
    var hardware: GANHardware?

    private var basis: simd_quatd?

    var hasOrientation = false

    var orientation: simd_quatd? {
        willSet {
            let shouldHaveOrientation = newValue != nil
            if hasOrientation != shouldHaveOrientation {
                hasOrientation = shouldHaveOrientation
            }
        }
    }

    enum SolveState {
        case solved(TimeInterval)
        case unsolved(Date)

        func unsolvedTime() -> TimeInterval {
            switch self {
            case .solved(let time): time
            case .unsolved(let date): -date.timeIntervalSinceNow
            }
        }
    }

    var rsCube = Cube()

    @ObservationIgnored
    var lastMove: Move?

    init(cube: GANCube) {
        self.cube = cube
    }

    func appear() async {
        @Sendable @MainActor func getBattery() async {
            batteryLevel = try? await cube.batteryLevel()
        }

        @Sendable @MainActor func getGyro() async {
            for await gyroData in cube.gyroData.values {
                let orient = gyroData.orientation
                // green facing us, white on top
                let home = simd_quatd(angle: Angle.degrees(180).radians, axis: SIMD3(0, 1, 0))
                let quat = simd_quatd(vector: simd_double4(-orient.x, orient.z, orient.y, orient.w)) * home
                let currentBasis: simd_quatd
                if let basis {
                    currentBasis = basis
                } else {
                    currentBasis = quat.conjugate
                    basis = currentBasis
                }
                self.orientation = currentBasis * quat
            }
        }

        @Sendable @MainActor func getMoves() async {
            for await move in cube.moves.values {
                let face: Face = switch move.face {
                case .back: .back
                case .front: .front
                case .left: .left
                case .right: .right
                case .down: .bottom
                case .up: .top
                }
                let magnitude: Move.Magnitude = switch move.direction {
                case .anticlockwise: .counterClockwiseQuarterTurn
                case .clockwise: .clockwiseQuarterTurn
                }
                let move = Move(face: face, magnitude: magnitude)
                lastMove = move
                rsCube.apply(move)
            }
        }

        @Sendable @MainActor func getHardware() async {
            self.hardware = try? await cube.hardware()
        }

        if let facelets = try? await cube.facelets() {
            rsCube = facelets.cube()!
        }

        async let battery: Void = getBattery()
        async let gyro: Void = getGyro()
        async let hardware: Void = getHardware()
        async let moves: Void = getMoves()

        _ = await (battery, gyro, hardware, moves)
    }

    func calibrate() {
        basis = nil
        rsCube = Cube()
        Task { try await cube.reset() }
    }
}

@MainActor
struct CubeView: View {
    let cubeVM: CubeViewModel

    @State private var startTime: Date?

    @State private var isSolving = false

    #if os(visionOS)
    @Environment(\.openImmersiveSpace) var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) var dismissImmersiveSpace
    #endif

    var isSolved: Bool {
        cubeVM.rsCube == .solved
    }

    var body: some View {
        VStack {
            Text("Solved: \(cubeVM.rsCube == .solved)")

            if let batteryLevel = cubeVM.batteryLevel {
                Text("Battery: \(batteryLevel, format: .number.precision(.integerLength(2...2)))%")
            } else {
                ProgressView("Loading battery")
            }

            if let hardware = cubeVM.hardware {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Hardware name:")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text(hardware.hardwareName)
                            .font(.body)
                            .fontWeight(.medium)
                    }
                    HStack {
                        Text("Software:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text(hardware.softwareVersion)
                            .font(.body)
                            .fontWeight(.medium)
                    }
                    HStack {
                        Text("Hardware version:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text(hardware.hardwareVersion)
                            .font(.body)
                            .fontWeight(.medium)
                    }
                    HStack {
                        Text("Gyroscope:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text(hardware.supportsGyroscope ? "Supported" : "Not Supported")
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(hardware.supportsGyroscope ? .green : .red)
                    }
                }
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(12)
            } else {
                ProgressView("Loading hardware")
            }

            if cubeVM.hasOrientation {
                CubeRealityView(cubeVM: cubeVM)

                #if os(visionOS)
                Button("Calibrate") {
                    Task {
                        await openImmersiveSpace(id: CalibrateView.spaceID)
                    }
                }

                Toggle("Solve Mode", isOn: $isSolving)
                    .onChange(of: isSolving) { _, isSolving in
                        Task {
                            if isSolving {
                                await openImmersiveSpace(id: SolveView.spaceID)
                            } else {
                                await dismissImmersiveSpace()
                            }
                        }
                    }
                    .fixedSize(horizontal: true, vertical: false)
                #else
                Button("Calibrate") {
                    cubeVM.calibrate()
                }
                #endif
            } else {
                ProgressView("Loading gyro")
            }
        }
        .task {
            await cubeVM.appear()
        }
        .onAppear {
            cubeVM.makeCurrent()
        }
        .onChange(of: isSolved) { old, new in
            guard old != new else { return }
            if new {
                
            }
        }
    }
}

#if os(visionOS)
import ARKit
#endif
import RealityKit

struct CubeRealityView: View {
    let cubeVM: CubeViewModel

    var body: some View {
        RealityView { content in
            let entity = CubeEntity(cubeVM: cubeVM)
            content.add(entity)
        }
    }
}

final class CubeEntity: Entity {
    init(cubeVM: CubeViewModel?) {
        super.init()
        self.setup(cubeVM: cubeVM)
    }

    required init() {
        super.init()
        self.setup(cubeVM: nil)
    }

    private var lastAnimationForEntity: [UInt64: (AnimationPlaybackController, Transform)] = [:]

    private func setup(cubeVM: CubeViewModel?) {
        let cubeSize: Float = 0.0575
        let size: Float
        #if os(visionOS)
        size = cubeSize
        #else
        size = 1
        #endif

        let relativeCornerRadius: Float = 0.05
        let relativePadding: Float = 1.0

        let cubeeSize = size / 3
        let cubeeMesh = MeshResource.generateBox(
            width: cubeeSize,
            height: cubeeSize,
            depth: cubeeSize,
            cornerRadius: cubeeSize * relativeCornerRadius,
            splitFaces: true
        )

        // the order of face materials expected by the box mesh resource
        // with splitFaces=true
        let faceOrder: [Face] = [.front, .top, .back, .bottom, .right, .left]

        let centerEntities = Face.allCases.map { loc in
            let colors = faceOrder.map { loc == $0 ? $0.color : .black }
            let materials = colors.map { SimpleMaterial(color: $0, roughness: 1.0, isMetallic: false) }
            let entity = ModelEntity(mesh: cubeeMesh, materials: materials)
            entity.transform.translation = loc.offset * cubeeSize * relativePadding
            self.addChild(entity)
            return entity
        }

        let cornerEntities = CornerLocation.allCases.map { loc in
            let colors: [SimpleMaterial.Color] = faceOrder.map { loc.faces.contains($0) ? $0.color : .black }
            let materials = colors.map { SimpleMaterial(color: $0, roughness: 1.0, isMetallic: false) }
            let entity = ModelEntity(mesh: cubeeMesh, materials: materials)
            self.addChild(entity)
            return entity
        }

        let edgeEntities = EdgeLocation.allCases.map { loc in
            let colors: [SimpleMaterial.Color] = faceOrder.map { loc.faces.contains($0) ? $0.color : .black }
            let materials = colors.map { SimpleMaterial(color: $0, roughness: 1.0, isMetallic: false) }
            let entity = ModelEntity(mesh: cubeeMesh, materials: materials)
            self.addChild(entity)
            return entity
        }

        if let cubeVM {
            observeChanges { [weak self] in
                guard let self else { return }

                let cube = cubeVM.rsCube

                for (animation, _) in lastAnimationForEntity.values {
                    // complete current animations
                    animation.time = animation.duration
                }

                let move = cubeVM.lastMove
                cubeVM.lastMove = nil

                if let move {
                    let center = centerEntities[move.face.rawValue]
                    center.transform.rotation = .init(.identity)
                    animate(move, on: center, start: center.transform)
                }

                // the location that the corner will be in
                for cornerDrawLocation in CornerLocation.allCases {
                    let corner = cube.corners[cornerDrawLocation]
                    // the corner that will be in this location
                    let cornerSourceLocation = corner.location
                    let cornerEntity = cornerEntities[cornerSourceLocation.rawValue]

                    let startTransform = cornerEntity.transform

                    cornerEntity.transform.translation = cornerDrawLocation.offset * cubeeSize * relativePadding

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
                        animate(move, on: cornerEntity, start: startTransform)
                    }
                }

                for edgeDrawLocation in EdgeLocation.allCases {
                    let edge = cube.edges[edgeDrawLocation]
                    let edgeSourceLocation = edge.location
                    let edgeEntity = edgeEntities[edgeSourceLocation.rawValue]

                    let startTransform = edgeEntity.transform

                    edgeEntity.transform.translation = edgeDrawLocation.offset * cubeeSize * relativePadding

                    let sourceRotation = edgeSourceLocation.referenceRotation
                    let drawRotation = edgeDrawLocation.referenceRotation
                    let degrees: Double = edge.orientation == .flipped ? 180 : 0
                    let orient = Rotation3D(angle: .degrees(degrees), axis: .yz)
                    edgeEntity.transform.rotation = simd_quatf(drawRotation * orient * sourceRotation.inverse)

                    if let move, edgeDrawLocation.faces.contains(move.face) {
                        animate(move, on: edgeEntity, start: startTransform)
                    }
                }
            }

            observeChanges { [weak self] in
                guard let self else { return }
                if let orientation = cubeVM.orientation {
                    self.orientation = simd_quatf(vector: simd_float4(orientation.vector))
                }
            }
        }
    }

    private func animate(_ move: Move, on entity: Entity, start: Transform) {
        let startT = lastAnimationForEntity[entity.id]?.1 ?? start
        let end = entity.transform
        let animation = OrbitAnimation(
            duration: 0.1,
            axis: move.face.offset,
            startTransform: startT,
            spinClockwise: move.magnitude != .counterClockwiseQuarterTurn,
            orientToPath: true,
            rotationCount: move.magnitude == .halfTurn ? 0.5 : 0.25,
            bindTarget: .transform
        )
        let resource = try! AnimationResource.generate(with: animation)
        let cont = entity.playAnimation(resource)
        lastAnimationForEntity[entity.id] = (cont, end)
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
    fileprivate var offset: SIMD3<Float> {
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
    fileprivate var color: SimpleMaterial.Color {
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

func observeChanges(_ changes: @escaping () -> Void) {
    withObservationTracking {
        changes()
    } onChange: {
        Task { @MainActor in observeChanges(changes) }
    }
}

#Preview {
    ContentView()
}
