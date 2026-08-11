import SwiftUI

struct SavedView: View {
    @Environment(NewsStore.self) private var store

    private var savedStories: [Story] {
        Story.all.filter { store.savedStoryIDs.contains($0.id) }
    }

    var body: some View {
        Group {
            if savedStories.isEmpty {
                ContentUnavailableView {
                    Label("Keep the good ones close", systemImage: "bookmark")
                } description: {
                    Text("Save a story from the feed or article reader and it will appear here.")
                }
            } else {
                List(savedStories) { story in
                    NavigationLink(value: story) {
                        Text(story.title)
                            .font(OvertureTheme.editorial(24))
                            .padding(.vertical, 8)
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Saved")
    }
}

#Preview("Empty") {
    NavigationStack { SavedView() }
        .environment(NewsStore())
}
