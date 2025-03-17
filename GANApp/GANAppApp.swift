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
            }
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)

        ImmersiveSpace(id: CalibrateView.spaceID) {
            if let cube = CubeViewModelManager.shared.current {
                CalibrateView(cubeVM: cube)
            }
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
        #endif
    }
}
