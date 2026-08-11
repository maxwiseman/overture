import MapKit
import SwiftUI
import UIKit
import WebKit

struct UpcomingView: View {
    @State private var launchState: LaunchLoadState = .loading
    @Namespace private var launchNamespace

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    Text("Rocket launches and other moments worth watching.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 8)

                    content
                }
                .frame(width: max(0, proxy.size.width - 40), alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
            }
        }
        .background(Color(.systemBackground))
        .navigationTitle("Upcoming")
        .task {
            await loadLaunches()
        }
        .refreshable {
            await loadLaunches(forceRefresh: true)
        }
        .navigationDestination(for: RocketLaunch.self) { launch in
            RocketLaunchDetailView(launch: launch, namespace: launchNamespace)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch launchState {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
        case .loaded(let launches):
            ForEach(launches) { launch in
                NavigationLink(value: launch) {
                    RocketLaunchCard(launch: launch)
                        .matchedTransitionSource(id: launch.id, in: launchNamespace)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        case .failed:
            Text("Using placeholder launch data until the live schedule is available.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            ForEach(RocketLaunch.placeholderLaunches) { launch in
                NavigationLink(value: launch) {
                    RocketLaunchCard(launch: launch)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func loadLaunches(forceRefresh: Bool = false) async {
        if case .loaded = launchState, !forceRefresh {
            return
        }

        if forceRefresh {
            launchState = .loading
        }

        do {
            let launches = try await LaunchLibraryClient().upcomingLaunches(forceRefresh: forceRefresh)
            launchState = .loaded(launches.isEmpty ? RocketLaunch.placeholderLaunches : launches)
        } catch {
            if case .loaded = launchState {
                return
            } else {
                launchState = .failed
            }
        }
    }
}

private enum LaunchLoadState {
    case loading
    case loaded([RocketLaunch])
    case failed
}

private struct RocketLaunchCard: View {
    let launch: RocketLaunch

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            LaunchImage(url: launch.imageURL)
                .frame(height: 210)
                .overlay(alignment: .topLeading) {
                    Text(launch.status)
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 10)
                        .frame(height: 30)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(12)
                }

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 14) {
                    launchBadge

                    VStack(alignment: .leading, spacing: 6) {
                        Text(launch.mission)
                            .font(OvertureTheme.editorial(28, weight: .semibold))
                            .lineSpacing(1)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(launch.vehicle)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(OvertureTheme.cobalt)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Spacer(minLength: 8)
                }

                Text(launch.summary)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineSpacing(4)
                    .lineLimit(3)

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 14) {
                        metadataLabel(launch.launchWindow, systemImage: "clock")
                        metadataLabel(launch.site, systemImage: "mappin.and.ellipse")
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        metadataLabel(launch.launchWindow, systemImage: "clock")
                        metadataLabel(launch.site, systemImage: "mappin.and.ellipse")
                    }
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 18))
        .clipShape(.rect(cornerRadius: 18))
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private func metadataLabel(_ text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .lineLimit(1)
            .truncationMode(.tail)
    }

    private var launchBadge: some View {
        VStack(spacing: 2) {
            Text(launch.month)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
            Text(launch.day)
                .font(.title3.weight(.bold))
        }
        .frame(width: 54, height: 58)
        .background(Color(.tertiarySystemBackground), in: .rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(.separator)
        )
    }
}

private struct RocketLaunchDetailView: View {
    let launch: RocketLaunch
    let namespace: Namespace.ID

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    LaunchImage(url: launch.imageURL)
                        .frame(width: proxy.size.width, height: 330)
                        .matchedTransitionSource(id: launch.id, in: namespace)

                    VStack(alignment: .leading, spacing: 18) {
                        Text(launch.status)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(OvertureTheme.cobalt)

                        Text(launch.mission)
                            .font(OvertureTheme.editorial(42, weight: .semibold))
                            .lineSpacing(-1)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(launch.summary)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .lineSpacing(5)
                            .fixedSize(horizontal: false, vertical: true)

                        LaunchDetailGrid(launch: launch)

                        LaunchSiteMap(launch: launch)

                        LivestreamSection(videoURL: launch.videoURL)
                    }
                    .frame(width: max(0, proxy.size.width - 40), alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 36)
                }
                .frame(width: proxy.size.width, alignment: .leading)
            }
        }
        .background(Color(.systemBackground))
        .navigationTitle(launch.shortTitle)
        .navigationBarTitleDisplayMode(.inline)
        .navigationTransition(.zoom(sourceID: launch.id, in: namespace))
    }
}

private struct LaunchDetailGrid: View {
    let launch: RocketLaunch
    private let columns = [
        GridItem(.flexible(minimum: 0), spacing: 14),
        GridItem(.flexible(minimum: 0), spacing: 14),
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
            detail("Vehicle", launch.vehicle)
            detail("Provider", launch.provider)
            detail("Window", launch.launchWindow)
            detail("Orbit", launch.orbit)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 18))
    }

    private func detail(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .lineLimit(4)
                .minimumScaleFactor(0.82)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct LaunchSiteMap: View {
    let launch: RocketLaunch

    var body: some View {
        if let coordinate = launch.coordinate {
            VStack(alignment: .leading, spacing: 12) {
                Text("Launch Site")
                    .font(.headline)

                Map(initialPosition: .region(region(for: coordinate))) {
                    Marker(launch.site, coordinate: coordinate)
                }
                .mapStyle(.imagery(elevation: .realistic))
                .frame(height: 230)
                .frame(maxWidth: .infinity)
                .clipShape(.rect(cornerRadius: 18))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func region(for coordinate: CLLocationCoordinate2D) -> MKCoordinateRegion {
        MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.55, longitudeDelta: 0.55)
        )
    }
}

private struct LivestreamSection: View {
    let videoURL: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Livestream")
                .font(.headline)

            if let embedURL {
                GeometryReader { proxy in
                    WebView(url: embedURL)
                        .frame(width: proxy.size.width, height: 220)
                        .clipShape(.rect(cornerRadius: 18))
                }
                .frame(height: 220)
            } else if let videoURL {
                Link(destination: videoURL) {
                    Label("Open livestream", systemImage: "play.rectangle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            } else {
                ContentUnavailableView(
                    "No livestream yet",
                    systemImage: "play.slash",
                    description: Text("Streams usually appear closer to launch.")
                )
                .frame(minHeight: 160)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var embedURL: URL? {
        guard let videoURL, videoURL.host()?.contains("youtube.com") == true else { return nil }
        guard let components = URLComponents(url: videoURL, resolvingAgainstBaseURL: false),
              let videoID = components.queryItems?.first(where: { $0.name == "v" })?.value else {
            return nil
        }
        return URL(string: "https://www.youtube.com/embed/\(videoID)")
    }
}

private struct LaunchImage: View {
    let url: URL?
    @State private var image: UIImage?
    @State private var didFail = false

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                fallback

                if url != nil, !didFail {
                    ProgressView()
                }
            }
        }
        .frame(maxWidth: .infinity)
        .clipped()
        .task(id: url) {
            await loadImage()
        }
    }

    private var fallback: some View {
        ZStack {
            LinearGradient(
                colors: [
                    OvertureTheme.cobalt.opacity(0.75),
                    Color(.secondarySystemBackground),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Image(systemName: "sparkles")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(.white.opacity(0.78))
        }
    }

    private func loadImage() async {
        image = nil
        didFail = false

        guard let url else { return }

        do {
            image = try await CachedImageLoader.shared.image(for: url)
        } catch {
            didFail = true
        }
    }
}

private struct WebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.scrollView.isScrollEnabled = false
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        webView.load(URLRequest(url: url))
    }
}

private struct RocketLaunch: Identifiable, Hashable {
    let id: String
    let mission: String
    let shortTitle: String
    let vehicle: String
    let provider: String
    let launchWindow: String
    let site: String
    let month: String
    let day: String
    let summary: String
    let status: String
    let orbit: String
    let imageURL: URL?
    let videoURL: URL?
    let latitude: Double?
    let longitude: Double?

    var coordinate: CLLocationCoordinate2D? {
        guard let latitude, let longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    static let placeholderLaunches = [
        RocketLaunch(
            id: "artemis-cargo-demo",
            mission: "Artemis Cargo Demo",
            shortTitle: "Artemis Cargo",
            vehicle: "SLS Block 1B",
            provider: "NASA",
            launchWindow: "Tue, 8:34 PM",
            site: "Kennedy LC-39B",
            month: "SEP",
            day: "03",
            summary: "A heavy-lift demonstration carrying logistics hardware for future lunar surface work.",
            status: "Placeholder",
            orbit: "Trans-lunar injection",
            imageURL: nil,
            videoURL: nil,
            latitude: 28.6272,
            longitude: -80.6209
        ),
        RocketLaunch(
            id: "starship-flight-14",
            mission: "Starship Flight 14",
            shortTitle: "Starship",
            vehicle: "Starship Super Heavy",
            provider: "SpaceX",
            launchWindow: "Fri, 7:10 AM",
            site: "Starbase",
            month: "SEP",
            day: "12",
            summary: "A full-stack test focused on ship reuse, booster recovery, and high-energy coast operations.",
            status: "Placeholder",
            orbit: "Suborbital",
            imageURL: nil,
            videoURL: nil,
            latitude: 25.9971,
            longitude: -97.1568
        ),
    ]
}

private struct LaunchLibraryClient {
    func upcomingLaunches(forceRefresh: Bool = false) async throws -> [RocketLaunch] {
        if !forceRefresh, let cachedLaunches = await LaunchLibraryCache.shared.cachedLaunches {
            return cachedLaunches
        }

        var components = URLComponents(string: "https://ll.thespacedevs.com/2.3.0/launches/upcoming/")!
        components.queryItems = [
            URLQueryItem(name: "limit", value: "10"),
            URLQueryItem(name: "mode", value: "detailed"),
            URLQueryItem(name: "format", value: "json"),
        ]

        let (data, response) = try await URLSession.shared.data(from: components.url!)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload = try decoder.decode(LaunchLibraryResponse.self, from: data)
        let launches = payload.results.map(RocketLaunch.init(response:))
        await LaunchLibraryCache.shared.store(launches)
        return launches
    }
}

private actor LaunchLibraryCache {
    static let shared = LaunchLibraryCache()

    private var launches: [RocketLaunch]?
    private var cachedAt: Date?
    private let timeToLive: TimeInterval = 30 * 60

    var cachedLaunches: [RocketLaunch]? {
        guard let launches, let cachedAt else { return nil }
        guard Date().timeIntervalSince(cachedAt) < timeToLive else { return nil }
        return launches
    }

    func store(_ launches: [RocketLaunch]) {
        self.launches = launches
        cachedAt = Date()
    }
}

private actor CachedImageLoader {
    static let shared = CachedImageLoader()

    private let cache: URLCache = {
        let cache = URLCache(
            memoryCapacity: 40 * 1024 * 1024,
            diskCapacity: 160 * 1024 * 1024,
            diskPath: "OvertureLaunchImages"
        )
        return cache
    }()

    func image(for url: URL) async throws -> UIImage {
        let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad)

        if let cachedResponse = cache.cachedResponse(for: request),
           let image = UIImage(data: cachedResponse.data) {
            return image
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let image = UIImage(data: data) else {
            throw URLError(.cannotDecodeContentData)
        }

        cache.storeCachedResponse(CachedURLResponse(response: response, data: data), for: request)
        return image
    }
}

private struct LaunchLibraryResponse: Decodable {
    let results: [LaunchLibraryLaunch]
}

private struct LaunchLibraryLaunch: Decodable {
    let id: String
    let name: String
    let status: LaunchStatus?
    let net: Date?
    let image: LaunchImageResource?
    let launchServiceProvider: LaunchProvider?
    let rocket: LaunchRocket?
    let mission: LaunchMission?
    let pad: LaunchPad?
    let vidURLs: [LaunchVideo]?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case status
        case net
        case image
        case launchServiceProvider = "launch_service_provider"
        case rocket
        case mission
        case pad
        case vidURLs = "vid_urls"
    }
}

private struct LaunchStatus: Decodable {
    let name: String
    let abbrev: String?
}

private struct LaunchImageResource: Decodable {
    let imageURL: URL?
    let thumbnailURL: URL?

    enum CodingKeys: String, CodingKey {
        case imageURL = "image_url"
        case thumbnailURL = "thumbnail_url"
    }
}

private struct LaunchProvider: Decodable {
    let name: String
}

private struct LaunchRocket: Decodable {
    let configuration: LaunchRocketConfiguration?
}

private struct LaunchRocketConfiguration: Decodable {
    let fullName: String?
    let name: String?
    let image: LaunchImageResource?

    enum CodingKeys: String, CodingKey {
        case fullName = "full_name"
        case name
        case image
    }
}

private struct LaunchMission: Decodable {
    let name: String?
    let description: String?
    let image: LaunchImageResource?
    let orbit: LaunchOrbit?
}

private struct LaunchOrbit: Decodable {
    let name: String?
    let abbrev: String?
}

private struct LaunchPad: Decodable {
    let name: String
    let latitude: Double?
    let longitude: Double?
    let image: LaunchImageResource?
    let location: LaunchLocation?
}

private struct LaunchLocation: Decodable {
    let name: String?
    let latitude: Double?
    let longitude: Double?
    let image: LaunchImageResource?
}

private struct LaunchVideo: Decodable {
    let priority: Int?
    let title: String?
    let featureImage: URL?
    let url: URL?
    let live: Bool?

    enum CodingKeys: String, CodingKey {
        case priority
        case title
        case featureImage = "feature_image"
        case url
        case live
    }
}

private extension RocketLaunch {
    init(response: LaunchLibraryLaunch) {
        let launchDate = response.net ?? Date()
        let missionName = response.mission?.name ?? response.name
        let preferredVideo = response.vidURLs?
            .sorted { ($0.priority ?? Int.max) < ($1.priority ?? Int.max) }
            .first

        self.init(
            id: response.id,
            mission: missionName,
            shortTitle: missionName.components(separatedBy: "|").last?.trimmingCharacters(in: .whitespacesAndNewlines) ?? missionName,
            vehicle: response.rocket?.configuration?.fullName ?? response.rocket?.configuration?.name ?? "Rocket",
            provider: response.launchServiceProvider?.name ?? "Launch provider",
            launchWindow: Self.windowFormatter.string(from: launchDate),
            site: [response.pad?.name, response.pad?.location?.name]
                .compactMap { $0 }
                .joined(separator: " · "),
            month: Self.monthFormatter.string(from: launchDate).uppercased(),
            day: Self.dayFormatter.string(from: launchDate),
            summary: response.mission?.description ?? preferredVideo?.title ?? "Mission details will appear as the launch provider publishes them.",
            status: response.status?.abbrev ?? response.status?.name ?? "Upcoming",
            orbit: response.mission?.orbit?.abbrev ?? response.mission?.orbit?.name ?? "TBD",
            imageURL: response.image?.imageURL
                ?? response.mission?.image?.imageURL
                ?? response.rocket?.configuration?.image?.imageURL
                ?? response.pad?.image?.imageURL
                ?? response.pad?.location?.image?.imageURL
                ?? preferredVideo?.featureImage,
            videoURL: preferredVideo?.url,
            latitude: response.pad?.latitude ?? response.pad?.location?.latitude,
            longitude: response.pad?.longitude ?? response.pad?.location?.longitude
        )
    }

    private static let windowFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter
    }()

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter
    }()
}

#Preview {
    NavigationStack { UpcomingView() }
}
