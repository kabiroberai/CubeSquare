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
            #if os(visionOS)
            HStack {
                ScenePicker()
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.bottom, 32)
            }
            #else
            Button("Calibrate") {
                cubeVM.calibrate()
            }
            #endif

            if let hardware = cubeVM.hardware {
                VStack {
                    Text(hardware.hardwareName)
                        .font(.title2)
                        .padding(.bottom, 16)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Battery:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            if let batteryLevel = cubeVM.batteryLevel {
                                Text("\(batteryLevel, format: .number.precision(.integerLength(2...2)))%")
                                    .font(.body)
                                    .fontWeight(.medium)
                            } else {
                                ProgressView("Loading battery")
                            }
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
                            Text("Hardware:")
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
                }
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(12)
            } else {
                ProgressView("Loading hardware")
            }

            if cubeVM.hasOrientation {
                CubeRealityView(cubeVM: cubeVM)
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

struct ScenePicker: View {
    @State private var selectedScene: String?
    @Environment(\.openImmersiveSpace) private var open
    @Environment(\.dismissImmersiveSpace) private var dismiss

    private var actuallyVisible: String? {
        ImmersiveSpaceManager.shared.visible
    }

    var body: some View {
        Picker(selection: $selectedScene) {
            Text("Home")
                .tag(String?.none)

            Label("Calibrate", systemImage: "dot.scope")
                .tag(CalibrateView.spaceID)

            Label("Timer", systemImage: "timer")
                .tag(TimerView.spaceID)
        } label: {
            Text("Home")
        }
        .pickerStyle(.segmented)
        .onChange(of: selectedScene) { _, new in
            Task {
                if let new {
                    await open(id: new)
                } else if actuallyVisible != nil {
                    await dismiss()
                }
            }
        }
        .onChange(of: actuallyVisible) { _, new in
            selectedScene = new
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
