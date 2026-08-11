import SwiftUI

@main
struct OvertureApp: App {
    @State private var store = NewsStore()

    var body: some Scene {
        WindowGroup {
            AppView()
                .environment(store)
                .tint(OvertureTheme.cobalt)
        }
    }
}
