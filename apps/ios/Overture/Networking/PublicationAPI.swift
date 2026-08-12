import Foundation

enum OvertureEnvironment {
    static let apiBaseURL: URL = {
        let configuredURL = Bundle.main.object(forInfoDictionaryKey: "OvertureAPIBaseURL") as? String
        return URL(string: configuredURL ?? "http://localhost:3001")!
    }()
}

struct PublicationEdition: Decodable {
    let id: String
    let slug: String
    let title: String
    let description: String
    let releaseDate: Date
    private let storyDocuments: [PublicationStory]

    enum CodingKeys: String, CodingKey {
        case id, slug, title, description, releaseDate
        case storyDocuments = "stories"
    }

    var stories: [Story] {
        storyDocuments.map(\.story)
    }
}

private struct PublicationStory: Decodable {
    let id: String
    let slug: String
    let title: String
    let deck: String
    let byline: String
    let category: String
    let readTimeMinutes: Int
    let publishedAt: Date?
    let heroImageURL: URL?
    let sections: [PublicationSection]

    var story: Story {
        Story(
            id: id,
            title: title,
            deck: deck,
            readTime: "\(readTimeMinutes) min read",
            category: category,
            imageName: fallbackImageName,
            imageURL: heroImageURL,
            byline: byline,
            publishedAt: publishedAt,
            sections: sections.map(\.articleSection)
        )
    }

    private var fallbackImageName: String {
        switch slug {
        case "paper-battery": "PaperBattery"
        case "laundry-robot": "LaundryRobot"
        default: "QuietFlight"
        }
    }
}

private struct PublicationSection: Decodable {
    let id: String
    let heading: String?
    let body: String

    var articleSection: ArticleSection {
        ArticleSection(
            id: id,
            heading: heading,
            glance: body,
            brief: body,
            standard: body,
            full: body
        )
    }
}

enum PublicationAPIError: LocalizedError {
    case invalidResponse
    case server(Int)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: "The publication API returned an invalid response."
        case .server(let status): "The publication API returned status \(status)."
        }
    }
}

actor PublicationAPI {
    static let shared = PublicationAPI()

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let value = try decoder.singleValueContainer().decode(String.self)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: value) {
                return date
            }
            formatter.formatOptions = [.withInternetDateTime]
            guard let date = formatter.date(from: value) else {
                throw DecodingError.dataCorruptedError(
                    in: try decoder.singleValueContainer(),
                    debugDescription: "Invalid ISO 8601 date: \(value)"
                )
            }
            return date
        }
        return decoder
    }()

    func currentEdition() async throws -> PublicationEdition {
        let url = OvertureEnvironment.apiBaseURL.appending(path: "api/publication/editions/current")
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let response = response as? HTTPURLResponse else {
            throw PublicationAPIError.invalidResponse
        }
        guard response.statusCode == 200 else {
            throw PublicationAPIError.server(response.statusCode)
        }
        return try decoder.decode(PublicationEdition.self, from: data)
    }
}
