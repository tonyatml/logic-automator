import SwiftUI

@main
struct ProjectExplorerApp: App {
    var body: some Scene {
        WindowGroup {
            ProjectExplorerView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
}
