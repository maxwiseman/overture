import SwiftUI

enum AppTab: Hashable {
    case home
    case explore
    case saved
    case launches
}

struct AppView: View {
    @Environment(NewsStore.self) private var store
    @State private var selectedTab: AppTab = .home
    @State private var homePath = NavigationPath()
    @State private var explorePath = NavigationPath()
    @State private var savedPath = NavigationPath()
    @State private var articleReading = ArticleReadingState()
    @State private var pendingArticleSlug: String?

    var body: some View {
        configuredTabView
            .environment(articleReading)
            .preferredColorScheme(activeColorScheme)
            .task {
                await store.loadPublication()
                openPendingArticleIfAvailable()
            }
            .task(priority: .utility) {
                await RocketModelView.prewarmCommonModel()
            }
            .onOpenURL { url in
                guard let slug = OvertureEnvironment.articleSlug(from: url) else { return }
                pendingArticleSlug = slug
                openPendingArticleIfAvailable()
            }
    }

    @ViewBuilder
    private var configuredTabView: some View {
        if #available(iOS 26.0, *) {
            tabs
                .tabBarMinimizeBehavior(.onScrollDown)
        } else {
            tabs
        }
    }

    private var tabs: some View {
        TabView(selection: tabSelection) {
            Tab("Home", systemImage: "newspaper", value: AppTab.home) {
                NewsNavigationStack(path: $homePath) {
                    HomeView()
                }
            }

            Tab(value: AppTab.explore, role: .search) {
                NewsNavigationStack(path: $explorePath) {
                    ExploreView()
                }
            }

            Tab("Saved", systemImage: "bookmark", value: AppTab.saved) {
                NewsNavigationStack(path: $savedPath) {
                    SavedView()
                }
            }

            Tab("Launches", systemImage: "paperplane", value: AppTab.launches) {
                NavigationStack {
                    LaunchesView()
                }
            }
        }
    }

    private var tabSelection: Binding<AppTab> {
        Binding(
            get: { selectedTab },
            set: { newTab in
                guard newTab != selectedTab else { return }
                selectedTab = newTab
                Haptics.selection()
            }
        )
    }

    private var activeColorScheme: ColorScheme? {
        switch selectedTab {
        case .home:
            homePath.isEmpty ? .dark : nil
        case .explore, .saved, .launches:
            nil
        }
    }

    private func openPendingArticleIfAvailable() {
        guard
            let pendingArticleSlug,
            let story = store.stories.first(where: { $0.slug == pendingArticleSlug })
        else { return }

        self.pendingArticleSlug = nil
        selectedTab = .home
        homePath = NavigationPath()
        homePath.append(story)
    }
}

private struct NewsNavigationStack<Content: View>: View {
    @Binding private var path: NavigationPath
    private let content: Content

    init(path: Binding<NavigationPath>, @ViewBuilder content: () -> Content) {
        self._path = path
        self.content = content()
    }

    var body: some View {
        NavigationStack(path: $path) {
            content
                .navigationDestination(for: Story.self) { story in
                    ArticleView(story: story)
                }
        }
    }
}

#Preview {
    AppView()
        .environment(NewsStore())
}
