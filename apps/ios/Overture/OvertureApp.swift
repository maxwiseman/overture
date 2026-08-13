import SwiftUI

@main
struct OvertureApp: App {
    @State private var store = NewsStore()
    @State private var authentication = AuthenticationSession()

    var body: some Scene {
        WindowGroup {
            rootView
        }
    }

    @ViewBuilder
    private var rootView: some View {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--share-success-preview") {
            ShareSuccessPreview()
        } else {
            appView
        }
        #else
        appView
        #endif
    }

    private var appView: some View {
        AppView()
            .environment(store)
            .environment(authentication)
            .tint(OvertureTheme.cobalt)
            .task {
                await authentication.restoreSession()
            }
    }
}

#if DEBUG
private struct ShareSuccessPreview: View {
    @State private var replayID = UUID()
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack(alignment: .bottom) {
            ShareImportView(
                extensionContext: nil,
                cancel: {},
                previewsSuccess: true
            )
            .id(replayID)

            Button {
                replayID = UUID()
            } label: {
                Label("Replay", systemImage: "arrow.counterclockwise")
                    .font(.body.weight(.semibold))
                    .padding(.horizontal, 8)
            }
            .buttonStyle(.glassProminent)
            .tint(colorScheme == .dark ? .white : .black)
            .padding(.bottom, 24)
            .accessibilityIdentifier("replay-share-success-animation")
        }
    }
}
#endif
