import Foundation

enum OvertureEnvironment {
    static let websiteBaseURL = URL(string: "https://maxw.news")!
    static let apiBaseURL = websiteBaseURL

    static func articleURL(slug: String) -> URL {
        websiteBaseURL
            .appending(path: "stories")
            .appending(path: slug)
    }

    static func articleSlug(from url: URL) -> String? {
        guard url.scheme == "https", url.host == websiteBaseURL.host else { return nil }

        let pathComponents = url.pathComponents.filter { $0 != "/" }
        guard pathComponents.count == 2, pathComponents[0] == "stories" else { return nil }
        return pathComponents[1]
    }
}
