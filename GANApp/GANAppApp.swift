import SwiftUI

@main
struct GANAppApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }

        #if os(visionOS)
        ImmersiveSpace(id: TimerView.spaceID) {
            if let cube = CubeViewModelManager.shared.current {
                TimerView(cubeVM: cube)
                    .task {
                        await ImmersiveSpaceManager.shared.acquire(id: TimerView.spaceID)
                    }
            }
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)

        ImmersiveSpace(id: CalibrateView.spaceID) {
            if let cube = CubeViewModelManager.shared.current {
                CalibrateView(cubeVM: cube)
                    .task {
                        await ImmersiveSpaceManager.shared.acquire(id: CalibrateView.spaceID)
                    }
            }
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)

        ImmersiveSpace(id: SolveView.spaceID) {
            if let cube = CubeViewModelManager.shared.current {
                SolveView(cubeVM: cube)
                    .task {
                        await ImmersiveSpaceManager.shared.acquire(id: SolveView.spaceID)
                    }
            }
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
        #endif
    }
}

@MainActor
@Observable
final class ImmersiveSpaceManager {
    static let shared = ImmersiveSpaceManager()

    private(set) var visible: String?

    private init() {}

    func acquire(id: String) async {
        visible = id
        for await _ in AsyncStream<Never>.never {}
        visible = nil
    }
}

extension AsyncStream {
    fileprivate static var never: Self {
        AsyncStream { _ in }
    }
}
