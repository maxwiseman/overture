import Foundation

enum OvertureEnvironment {
    static let websiteBaseURL = URL(string: "https://maxw.news")!

    #if targetEnvironment(simulator)
    static let apiBaseURL = URL(string: "http://localhost:3001")!
    #else
    static let apiBaseURL = websiteBaseURL
    #endif

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
