import CubeKit
import SwiftUI
import simd
import RealityKit

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
                let quat = simd_quatd(vector: SIMD4(-orient.x, orient.z, orient.y, orient.w)) * home
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
                lastMove = move
                rsCube.apply(move)
            }
        }

        @Sendable @MainActor func getHardware() async {
            self.hardware = try? await cube.hardware()
        }

        if let facelets = try? await cube.facelets() {
            lastMove = nil
            rsCube = facelets
        }

        async let battery: Void = getBattery()
        async let gyro: Void = getGyro()
        async let hardware: Void = getHardware()
        async let moves: Void = getMoves()

        _ = await (battery, gyro, hardware, moves)
    }

    func calibrate() {
        basis = nil
        lastMove = nil
        rsCube = Cube()
        Task { try await cube.reset() }
    }
}

@MainActor
struct CubeView: View {
    let cubeVM: CubeViewModel

    @State private var isSolving = false

    #if os(visionOS)
    @Environment(\.openImmersiveSpace) var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) var dismissImmersiveSpace
    #endif

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
                        await dismissImmersiveSpace()
                        await openImmersiveSpace(id: CalibrateView.spaceID)
                    }
                }

                Toggle("Solve Mode", isOn: $isSolving)
                    .onChange(of: isSolving) { _, isSolving in
                        Task {
                            if isSolving {
                                await openImmersiveSpace(id: TimerView.spaceID)
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
    }
}

struct CubeRealityView: View {
    let cubeVM: CubeViewModel

    var body: some View {
        RealityView { content in
            let entity = CubeEntity(cubeVM: cubeVM)
            content.add(entity)
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
