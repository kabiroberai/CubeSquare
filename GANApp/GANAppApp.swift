import SwiftUI

@main
struct GANAppApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }

        #if os(visionOS)
        ImmersiveSpace(id: SolveView.spaceID) {
            if let cube = CubeViewModelManager.shared.current {
                SolveView(cubeVM: cube)
            }
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
        #endif
    }
}
