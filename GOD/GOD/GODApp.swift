import SwiftUI

@main
struct GODApp: App {
    @StateObject private var engine = GodEngine()

    var body: some Scene {
        WindowGroup {
            ContentView(engine: engine)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 600, height: 700)
    }
}
