import Observation

@MainActor
@Observable
final class NewsStore {
    var edition: Edition = .tomorrow
    var editionTitle = Edition.tomorrow.title
    var stories: [Story] = Story.all
    var publicationError: String?
    var savedStoryIDs: Set<String> = []
    var alertsEnabled = true
    var morningEditionNotifications = true
    var productUpdateNotifications = false
    var downloadSavedStories = true
    var openLinksInApp = true
    private var hasLoadedPublication = false

    func loadPublication(forceRefresh: Bool = false) async {
        guard forceRefresh || !hasLoadedPublication else { return }
        hasLoadedPublication = true

        do {
            let publication = try await PublicationAPI.shared.currentEdition()
            guard !publication.stories.isEmpty else { return }
            editionTitle = publication.title
            stories = publication.stories
            publicationError = nil
        } catch {
            publicationError = error.localizedDescription
        }
    }

    func isSaved(_ story: Story) -> Bool {
        savedStoryIDs.contains(story.id)
    }

    func toggleSaved(_ story: Story) {
        if savedStoryIDs.contains(story.id) {
            savedStoryIDs.remove(story.id)
        } else {
            savedStoryIDs.insert(story.id)
        }
        Haptics.impact()
    }
}

@MainActor
@Observable
final class ArticleReadingState {
    private var depthByStoryID: [String: ReadingDepth] = [:]

    var activeStory: Story?
    var previewDepth: ReadingDepth?
    var isPinching = false

    var selectedDepth: ReadingDepth {
        guard let activeStory else { return .full }
        return depthByStoryID[activeStory.id] ?? .full
    }

    var displayedDepth: ReadingDepth {
        previewDepth ?? selectedDepth
    }

    func activate(_ story: Story) {
        activeStory = story
        previewDepth = nil
        isPinching = false
    }

    func deactivate(_ story: Story) {
        guard activeStory?.id == story.id else { return }
        activeStory = nil
        previewDepth = nil
        isPinching = false
    }

    func beginPinch() {
        previewDepth = selectedDepth
        isPinching = true
    }

    func preview(_ depth: ReadingDepth) {
        previewDepth = depth
    }

    func commitPreview() {
        select(previewDepth ?? selectedDepth)
        previewDepth = nil
        isPinching = false
    }

    func select(_ depth: ReadingDepth) {
        guard let activeStory else { return }
        depthByStoryID[activeStory.id] = depth
    }
}
