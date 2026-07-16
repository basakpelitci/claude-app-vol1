import SwiftUI

@main
struct AuraApp: App {
    @State private var deps = AppDependencies.live()

    var body: some Scene {
        WindowGroup {
            RootTabView(deps: deps)
        }
    }
}
