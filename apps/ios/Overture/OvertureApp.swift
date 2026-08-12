import SwiftUI

@main
struct OvertureApp: App {
    @State private var store = NewsStore()
    @State private var authentication = AuthenticationSession()

    var body: some Scene {
        WindowGroup {
            AppView()
                .environment(store)
                .environment(authentication)
                .tint(OvertureTheme.cobalt)
                .task {
                    await authentication.restoreSession()
                }
        }
    }
}
