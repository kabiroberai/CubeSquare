import SwiftUI
import simd

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
final class CubeViewModel {
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
                let quat = simd_quatd(vector: simd_double4(-orient.x, orient.z, orient.y, orient.w))
                let currentBasis: simd_quatd
                if let basis {
                    currentBasis = basis
                } else {
                    currentBasis = quat.conjugate
                    basis = currentBasis
                }
                // green facing us, white on top
                let home = simd_quatd(angle: Angle.degrees(180).radians, axis: SIMD3(0, 1, 0))
                self.orientation = home * currentBasis * quat
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
                rsCube.apply(.init(face: face, magnitude: magnitude))
            }
        }

        @Sendable @MainActor func getHardware() async {
            self.hardware = try? await cube.hardware()
        }

        if let facelets = try? await cube.facelets() {
            rsCube = facelets.cube()
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

                Button("Calibrate") {
                    cubeVM.calibrate()
                }
            } else {
                ProgressView("Loading gyro")
            }
        }
        .task {
            await cubeVM.appear()
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
            let cubeeSize = 0.0575

            #if os(visionOS)
            Task {
                // doesn't work: requires immersive view
                let session = ARKitSession()
                let image = UIGraphicsImageRenderer(size: .init(width: 100, height: 100)).image { ctx in
                    UIColor.red.setFill()
                    ctx.fill(.init(x: 0, y: 0, width: 100, height: 100))
                }
                let cubee = cubeeSize / 3
                let ref = ReferenceImage(cgimage: image.cgImage!, physicalSize: .init(width: cubee, height: cubee))
                let imageTracker = ImageTrackingProvider(referenceImages: [ref])
                try await session.run([imageTracker])
                print("Starting tracking. Count = \(ref)")
                for await update in imageTracker.anchorUpdates {
                    print("Update: \(update)")
                }
                print("Done tracking")
                _ = session
            }
            #endif

            let size: Float
            #if os(visionOS)
            size = Float(cubeeSize)
            #else
            size = 1
            #endif
            let mesh = MeshResource.generateBox(width: size, height: size, depth: size, splitFaces: true)
            let colors: [SimpleMaterial.Color] = [.blue, .white, .green, .yellow, .orange, .red]
            let materials = colors.map { SimpleMaterial(color: $0, roughness: 1.0, isMetallic: false) }
            let entity = ModelEntity(mesh: mesh, materials: materials)
            content.add(entity)
            observeChanges {
                if let orientation = cubeVM.orientation {
                    entity.orientation = simd_quatf(vector: simd_float4(orientation.vector))
                }
            }
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
