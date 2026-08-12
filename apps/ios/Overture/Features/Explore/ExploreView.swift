import SwiftUI

struct ExploreView: View {
    @Environment(NewsStore.self) private var store
    @State private var query = ""

    private var filteredStories: [Story] {
        guard !query.isEmpty else { return store.stories }
        return store.stories.filter {
            $0.title.localizedCaseInsensitiveContains(query)
                || $0.category.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                Text("Ideas organized by the future they might create.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 26)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 9) {
                        ForEach(["Energy", "Robotics", "Space", "Biology", "Cities"], id: \.self) { topic in
                            Text(topic)
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 15)
                                .padding(.vertical, 9)
                                .overlay(Capsule().stroke(.separator))
                        }
                    }
                }
                .padding(.bottom, 28)

                ForEach(filteredStories) { story in
                    NavigationLink(value: story) {
                        ExploreRow(story: story)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)
        }
        .background(Color(.systemBackground))
        .navigationTitle("Explore")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $query, prompt: "Search ideas")
    }
}

private struct ExploreRow: View {
    let story: Story

    var body: some View {
        HStack(spacing: 16) {
            StoryImage(story: story)
                .frame(width: 116, height: 116)
                .clipShape(.rect(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 7) {
                Text(story.category.uppercased())
                    .font(.caption.weight(.bold))
                    .tracking(0.8)
                    .foregroundStyle(OvertureTheme.cobalt)
                Text(story.title)
                    .font(OvertureTheme.editorial(25))
                    .lineSpacing(1)
                Text(story.readTime)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 18)
        .overlay(alignment: .top) { Rectangle().fill(.separator).frame(height: 0.5) }
    }
}

#Preview {
    NavigationStack { ExploreView() }
}
