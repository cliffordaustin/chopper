import SwiftUI

@main
struct ChopperApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 960, height: 640)
    }
}
