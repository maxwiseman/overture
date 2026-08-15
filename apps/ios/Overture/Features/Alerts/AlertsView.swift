import MapKit
import SwiftUI
import UIKit
import WebKit

struct LaunchesView: View {
    @State private var launchState: LaunchLoadState = .loading
    @State private var isFetching = false
    @State private var isLoadingMore = false
    @State private var paginationErrorMessage: String?
    @Namespace private var launchNamespace

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 28) {
                content
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .background(Color(.systemBackground))
        .navigationTitle("Launches")
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
            launchList(RocketLaunch.placeholderLaunches, showsModels: false)
                .redacted(reason: .placeholder)
                .allowsHitTesting(false)
        case .loaded(let schedule):
            launchList(schedule.launches, nextOffset: schedule.nextOffset)
        case .failed(let message):
            VStack(alignment: .leading, spacing: 10) {
                Label(message, systemImage: "wifi.slash")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Button {
                    Task {
                        await loadLaunches(forceRefresh: true)
                    }
                } label: {
                    if isFetching {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label("Try Again", systemImage: "arrow.clockwise")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(isFetching)
            }

            launchList(RocketLaunch.placeholderLaunches, showsModels: false)
                .redacted(reason: .placeholder)
                .allowsHitTesting(false)
        }
    }

    private func launchList(
        _ launches: [RocketLaunch],
        nextOffset: Int? = nil,
        showsModels: Bool = true
    ) -> some View {
        let supportedLaunches = launches.filter {
            RocketModelView.supports(vehicle: $0.vehicle, spacecraft: $0.spacecraft)
        }

        return Group {
            if let nextLaunch = supportedLaunches.first {
                VStack(alignment: .leading, spacing: 12) {
                    LaunchSectionHeader(title: "Next launch")

                    NavigationLink(value: nextLaunch) {
                        LaunchCard(launch: nextLaunch, isNext: true, showsModel: showsModels)
                            .matchedTransitionSource(id: nextLaunch.id, in: launchNamespace)
                    }
                    .buttonStyle(.plain)
                    .onAppear {
                        guard supportedLaunches.count == 1, let nextOffset else { return }
                        Task {
                            await loadMoreLaunches(offset: nextOffset)
                        }
                    }
                }
            }

            if supportedLaunches.count > 1 {
                VStack(alignment: .leading, spacing: 12) {
                    LaunchSectionHeader(title: "Coming up", count: supportedLaunches.count - 1)

                    LazyVStack(spacing: 16) {
                        ForEach(supportedLaunches.dropFirst()) { launch in
                            NavigationLink(value: launch) {
                                LaunchCard(launch: launch, showsModel: showsModels)
                                    .matchedTransitionSource(id: launch.id, in: launchNamespace)
                            }
                            .buttonStyle(.plain)
                            .onAppear {
                                guard launch.id == supportedLaunches.last?.id,
                                      let nextOffset else {
                                    return
                                }
                                Task {
                                    await loadMoreLaunches(offset: nextOffset)
                                }
                            }
                        }
                    }
                }
            }

            if let nextOffset {
                paginationFooter(nextOffset: nextOffset)
            }
        }
    }

    @ViewBuilder
    private func paginationFooter(nextOffset: Int) -> some View {
        VStack(spacing: 10) {
            if isLoadingMore {
                ProgressView()
                    .accessibilityLabel("Loading more launches")
            } else if let paginationErrorMessage {
                Label(paginationErrorMessage, systemImage: "wifi.slash")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button("Try Loading More") {
                    Task {
                        await loadMoreLaunches(offset: nextOffset)
                    }
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private func loadLaunches(forceRefresh: Bool = false) async {
        guard !isFetching else { return }

        if case .loaded = launchState, !forceRefresh {
            return
        }

        isFetching = true
        paginationErrorMessage = nil
        defer { isFetching = false }

        do {
            let page = try await LaunchLibraryClient().upcomingLaunches(forceRefresh: forceRefresh)
            guard !Task.isCancelled else { return }
            launchState = .loaded(LaunchSchedule(
                launches: page.launches,
                nextOffset: page.nextOffset
            ))
        } catch is CancellationError {
            return
        } catch let error as URLError where error.code == .cancelled {
            return
        } catch {
            if case .loaded = launchState {
                return
            } else {
                launchState = .failed(Self.failureMessage(for: error))
            }
        }
    }

    private func loadMoreLaunches(offset: Int) async {
        guard !isLoadingMore,
              case .loaded(let currentSchedule) = launchState,
              currentSchedule.nextOffset == offset else {
            return
        }

        isLoadingMore = true
        paginationErrorMessage = nil
        defer { isLoadingMore = false }

        do {
            let page = try await LaunchLibraryClient().upcomingLaunches(offset: offset)
            guard !Task.isCancelled else { return }

            var launchesByID = Dictionary(
                uniqueKeysWithValues: currentSchedule.launches.map { ($0.id, $0) }
            )
            page.launches.forEach { launchesByID[$0.id] = $0 }

            launchState = .loaded(LaunchSchedule(
                launches: launchesByID.values.sorted { $0.date < $1.date },
                nextOffset: page.nextOffset
            ))
        } catch is CancellationError {
            return
        } catch let error as URLError where error.code == .cancelled {
            return
        } catch {
            paginationErrorMessage = "More launches couldn't be loaded."
        }
    }

    private static func failureMessage(for error: Error) -> String {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed:
                return "You're offline. Reconnect, then pull to refresh or try again."
            case .timedOut, .cannotConnectToHost, .cannotFindHost:
                return "The launch service couldn't be reached. Pull to refresh or try again."
            default:
                break
            }
        }

        return error.localizedDescription
    }
}

private enum LaunchLoadState {
    case loading
    case loaded(LaunchSchedule)
    case failed(String)
}

private struct LaunchSchedule {
    let launches: [RocketLaunch]
    let nextOffset: Int?
}

private struct LaunchSectionHeader: View {
    let title: String
    var count: Int?

    var body: some View {
        HStack {
            Text(title)
                .font(.headline)

            Spacer()

            if let count {
                Text(count, format: .number)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Color(.tertiarySystemFill), in: Capsule())
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct LaunchCard: View {
    let launch: RocketLaunch
    var isNext = false
    var showsModel = true
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color(.secondarySystemBackground)

            if showsModel && !dynamicTypeSize.isAccessibilitySize {
                RocketCardModelView(vehicle: launch.vehicle, spacecraft: launch.spacecraft)
                    .frame(width: 150, height: 320)
                    .padding(.trailing, -8)
                    .padding(.bottom, -6)
                    .allowsHitTesting(false)
            }

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(launch.statusColor)
                        .frame(width: 7, height: 7)

                    Text(launch.status.uppercased())
                        .font(.caption2.weight(.bold))
                        .tracking(0.8)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(.regularMaterial, in: Capsule())

                Spacer(minLength: 34)

                Text(launch.dateDisplayText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(launch.mission)
                    .font(OvertureTheme.editorial(34, weight: .semibold))
                    .tracking(-0.8)
                    .lineSpacing(-1)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 6)

                Text("\(launch.provider)  ·  \(launch.displayVehicle)")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .padding(.top, 8)

                Spacer(minLength: 22)

                if launch.showsCountdown {
                    LaunchCountdown(date: launch.date)
                }
            }
            .foregroundStyle(.primary)
            .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : 238, alignment: .leading)
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: dynamicTypeSize.isAccessibilitySize ? 440 : 390)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(isNext ? "Next launch" : "Upcoming launch"), \(launch.mission), \(launch.launchWindow), \(launch.site)")
    }
}

private struct LaunchDateLabel: View {
    let text: String
    var style: LaunchCountdown.Style = .dark

    var body: some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .modifier(LaunchCountdownBackground(style: style, isInteractive: false))
        .accessibilityLabel(text)
    }
}

private struct LaunchCountdown: View {
    let date: Date
    var style: Style = .dark
    var showsClock = true
    var allowsDateToggle = false
    @State private var showsLaunchDate = false

    enum Style {
        case dark
        case glass
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            if allowsDateToggle {
                Button {
                    withAnimation(.easeInOut(duration: 0.12)) {
                        showsLaunchDate.toggle()
                    }
                } label: {
                    content(from: context.date)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(showsLaunchDate ? "Launch date and time" : "Time until launch")
                .accessibilityValue(displayedText(from: context.date))
                .accessibilityHint(showsLaunchDate ? "Tap to show countdown" : "Tap to show launch date and time")
            } else {
                content(from: context.date)
                    .accessibilityLabel("Time until launch")
                    .accessibilityValue(countdown(from: context.date))
            }
        }
    }

    private func content(from now: Date) -> some View {
        HStack(spacing: 8) {
            if showsClock {
                Image(systemName: "clock")
                    .font(.caption.weight(.semibold))
            }

            ZStack {
                if showsLaunchDate {
                    Text(launchDate)
                        .transition(.opacity)
                } else {
                    Text(countdown(from: now))
                        .monospacedDigit()
                        .transition(.opacity)
                }
            }
            .font(.subheadline.weight(.semibold))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .contentShape(Capsule())
        .modifier(LaunchCountdownBackground(style: style, isInteractive: allowsDateToggle))
    }

    private var launchDate: String {
        date.formatted(date: .abbreviated, time: .shortened)
    }

    private func displayedText(from now: Date) -> String {
        showsLaunchDate ? launchDate : countdown(from: now)
    }

    private func countdown(from now: Date) -> String {
        let remaining = max(0, Int(date.timeIntervalSince(now)))
        let days = remaining / 86_400
        let hours = (remaining % 86_400) / 3_600
        let minutes = (remaining % 3_600) / 60
        let seconds = remaining % 60

        if remaining == 0 {
            return "Launching now"
        }

        if days > 0 {
            return String(format: "T−%dd %02d:%02d:%02d", days, hours, minutes, seconds)
        }

        return String(format: "T−%02d:%02d:%02d", hours, minutes, seconds)
    }
}

private struct LaunchCountdownBackground: ViewModifier {
    let style: LaunchCountdown.Style
    let isInteractive: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        switch style {
        case .dark:
            content
                .background(.black.opacity(0.46), in: Capsule())
                .foregroundStyle(.white)
        case .glass:
            content
                .foregroundStyle(.primary)
                .glassEffect(.regular.interactive(isInteractive), in: .capsule)
        }
    }
}

private struct RocketLaunchDetailView: View {
    let launch: RocketLaunch
    let namespace: Namespace.ID
    @Environment(\.dismiss) private var dismiss
    @State private var presentedSheet: LaunchDetailSheetDestination? = .details
    @State private var selectedDetent: PresentationDetent = .height(280)

    private var isInspectingModel: Bool {
        selectedDetent == .height(80)
    }

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            RocketDetailModelView(
                vehicle: launch.vehicle,
                spacecraft: launch.spacecraft,
                isCentered: isInspectingModel
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
            .shadow(color: .black.opacity(0.18), radius: 12)
            .zIndex(0)

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 14) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(launch.displayVehicle)
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .tracking(-0.8)
                            .lineLimit(3)

                        Text(launch.provider)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.top, 8)

                        VStack(alignment: .leading, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Intended orbit")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)

                                Text(launch.orbit)
                                    .font(.headline)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Status")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)

                                Text(launch.status)
                                    .font(.headline)
                            }
                        }
                        .padding(.top, 14)
                    }
                    .frame(maxWidth: 230, alignment: .leading)
                    .opacity(isInspectingModel ? 0 : 1)
                    .accessibilityHidden(isInspectingModel)
                    .allowsHitTesting(!isInspectingModel)

                    Spacer(minLength: 0)

                    Button {
                        closeLaunchDetails()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.body.weight(.semibold))
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                    .controlSize(.large)
                    .accessibilityLabel("Close launch details")
                }

                Spacer()

                HStack {
                    Spacer()
                    if launch.showsCountdown {
                        LaunchCountdown(
                            date: launch.date,
                            style: .glass,
                            showsClock: false,
                            allowsDateToggle: true
                        )
                    } else {
                        LaunchDateLabel(
                            text: launch.dateDisplayText,
                            style: .glass
                        )
                    }
                    Spacer()
                }
                .padding(.bottom, 286)
                .opacity(isInspectingModel ? 0 : 1)
                .accessibilityHidden(isInspectingModel)
                .allowsHitTesting(!isInspectingModel)
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .animation(.snappy(duration: 0.35), value: isInspectingModel)
            .zIndex(1)
        }
        .foregroundStyle(.primary)
        .tint(.primary)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .navigationTransition(.zoom(sourceID: launch.id, in: namespace))
        .background {
            NavigationBackSwipeDisabler()
                .frame(width: 0, height: 0)
        }
        .sheet(item: $presentedSheet) { _ in
            LaunchDetailSheet(
                launch: launch,
                isCompact: isInspectingModel
            )
                .presentationDetents(
                    [.height(80), .height(280), .large],
                    selection: $selectedDetent
                )
                .presentationDragIndicator(.visible)
                .presentationBackgroundInteraction(.enabled(upThrough: .height(280)))
                .interactiveDismissDisabled()
        }
    }

    private func closeLaunchDetails() {
        dismissSheetForNavigation()
        dismiss()
    }

    private func dismissSheetForNavigation() {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            selectedDetent = .height(80)
            presentedSheet = nil
        }
    }

}

private struct NavigationBackSwipeDisabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> NavigationBackSwipeDisablerViewController {
        NavigationBackSwipeDisablerViewController()
    }

    func updateUIViewController(
        _ uiViewController: NavigationBackSwipeDisablerViewController,
        context: Context
    ) {
        uiViewController.disableNavigationBackGestures()
    }

    static func dismantleUIViewController(
        _ uiViewController: NavigationBackSwipeDisablerViewController,
        coordinator: Void
    ) {
        uiViewController.restoreNavigationBackGestures()
    }
}

@MainActor
private final class NavigationBackSwipeDisablerViewController: UIViewController {
    private var disabledGestureRecognizers: [UIGestureRecognizer] = []

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        disableNavigationBackGestures()
    }

    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        if parent == nil {
            restoreNavigationBackGestures()
        } else {
            disableNavigationBackGestures()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        restoreNavigationBackGestures()
        super.viewWillDisappear(animated)
    }

    func disableNavigationBackGestures() {
        var viewController: UIViewController? = parent
        var gestures: [UIGestureRecognizer] = []

        while let current = viewController {
            gestures.append(contentsOf: current.view.gestureRecognizers?.filter { gesture in
                gesture is UIScreenEdgePanGestureRecognizer
                    || gesture.name?.localizedCaseInsensitiveContains("InteractiveDismiss") == true
            } ?? [])
            viewController = current.parent
        }

        if let navigationController = resolvedNavigationController() {
            gestures.append(contentsOf: [
                navigationController.interactivePopGestureRecognizer,
                navigationController.interactiveContentPopGestureRecognizer
            ].compactMap { $0 })
        }

        for gesture in gestures where gesture.isEnabled
            && !disabledGestureRecognizers.contains(where: { $0 === gesture }) {
            gesture.isEnabled = false
            disabledGestureRecognizers.append(gesture)
        }
    }

    func restoreNavigationBackGestures() {
        for gesture in disabledGestureRecognizers {
            gesture.isEnabled = true
        }
        disabledGestureRecognizers.removeAll()
    }

    private func resolvedNavigationController() -> UINavigationController? {
        if let navigationController {
            return navigationController
        }

        var ancestor = parent
        while let current = ancestor {
            if let navigationController = current as? UINavigationController {
                return navigationController
            }
            if let navigationController = current.navigationController {
                return navigationController
            }
            ancestor = current.parent
        }

        return findNavigationController(in: viewIfLoaded?.window?.rootViewController)
    }

    private func findNavigationController(in root: UIViewController?) -> UINavigationController? {
        guard let root else { return nil }
        if let navigationController = root as? UINavigationController {
            return navigationController
        }

        for child in root.children {
            if let navigationController = findNavigationController(in: child) {
                return navigationController
            }
        }

        return nil
    }
}

private enum LaunchDetailSheetDestination: String, Identifiable {
    case details

    var id: String { rawValue }
}

private struct LaunchDetailSheet: View {
    let launch: RocketLaunch
    let isCompact: Bool

    var body: some View {
        Group {
            if isCompact {
                compactContent
                    .transition(.opacity)
            } else {
                expandedContent
                    .transition(.opacity)
            }
        }
        .tint(.primary)
        .animation(.easeInOut(duration: 0.12), value: isCompact)
    }

    private var compactContent: some View {
        Text(launch.displayVehicle)
            .font(.title3.weight(.bold))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .padding(.horizontal, 36)
            .accessibilityAddTraits(.isHeader)
    }

    private var expandedContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    sheetTitle

                    Text(launch.summary)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .lineSpacing(5)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }

                LaunchDetailGrid(launch: launch)

                LaunchSiteMap(launch: launch)

                if launch.imageURL != nil {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Mission image")
                            .font(.headline)

                        LaunchImage(url: launch.imageURL)
                            .frame(height: 230)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                }

                LivestreamSection(videoURL: launch.videoURL)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 44)
        }
        .scrollIndicators(.hidden)
    }

    private var sheetTitle: some View {
        let title = LaunchMissionTitle(launch.mission)

        return VStack(spacing: 3) {
            Text(title.title)
                .font(.title2.weight(.bold))

            if let subtitle = title.subtitle {
                Text(subtitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

private struct LaunchMissionTitle {
    let title: String
    let subtitle: String?

    init(_ mission: String) {
        var title = mission
        var subtitleParts: [String] = []

        while let range = title.range(of: #"\([^()]*\)"#, options: .regularExpression) {
            subtitleParts.append(String(title[range]))
            title.removeSubrange(range)
        }

        if title.range(of: "Starlink", options: .caseInsensitive) != nil,
           let range = title.range(
               of: #"\bGroup\s+[A-Za-z0-9]+(?:-[A-Za-z0-9]+)+\b"#,
               options: [.regularExpression, .caseInsensitive]
           ) {
            subtitleParts.insert(String(title[range]), at: 0)
            title.removeSubrange(range)
        }

        self.title = title
            .replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.subtitle = subtitleParts.isEmpty ? nil : subtitleParts.joined(separator: " · ")
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
            detail("Vehicle", launch.displayVehicle)
            detail("Provider", launch.provider)
            detail("Orbit", launch.orbit)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.tertiarySystemBackground), in: .rect(cornerRadius: 18))
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

            if let videoID = youtubeVideoID, let videoURL {
                YouTubePlayerView(videoID: videoID)
                    .aspectRatio(16.0 / 9.0, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                Link(destination: videoURL) {
                    Label("Open in YouTube", systemImage: "arrow.up.right.square")
                        .font(.subheadline.weight(.semibold))
                }
            } else if let videoURL {
                Link(destination: videoURL) {
                    Label("Open livestream", systemImage: "play.rectangle")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.glass)
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

    private var youtubeVideoID: String? {
        guard let videoURL, let host = videoURL.host()?.lowercased() else { return nil }

        let candidate: String?
        if host == "youtu.be" || host.hasSuffix(".youtu.be") {
            candidate = videoURL.pathComponents.dropFirst().first
        } else if host.contains("youtube.com") || host.contains("youtube-nocookie.com") {
            let components = URLComponents(url: videoURL, resolvingAgainstBaseURL: false)
            let pathComponents = videoURL.pathComponents.filter { $0 != "/" }

            if let queryVideoID = components?.queryItems?.first(where: { $0.name == "v" })?.value {
                candidate = queryVideoID
            } else if pathComponents.first.map({ ["embed", "live", "shorts"].contains($0) }) == true {
                candidate = pathComponents.dropFirst().first
            } else {
                candidate = nil
            }
        } else {
            candidate = nil
        }

        guard let candidate, candidate.count == 11 else { return nil }
        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        guard candidate.unicodeScalars.allSatisfy(allowedCharacters.contains) else { return nil }
        return candidate
    }
}

private struct LaunchImage: View {
    let url: URL?
    @State private var image: UIImage?
    @State private var didFail = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                } else {
                    fallback

                    if url != nil, !didFail {
                        ProgressView()
                    }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .task(id: url) {
            await loadImage()
        }
    }

    private var fallback: some View {
        ZStack {
            Color(.tertiarySystemBackground)

            Image(systemName: "photo")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(.secondary)
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

private struct YouTubePlayerView: UIViewRepresentable {
    let videoID: String

    private static let clientOrigin = URL(string: "https://overture.news/")!

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.isOpaque = false
        webView.backgroundColor = .clear
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.loadedVideoID != videoID else { return }
        context.coordinator.loadedVideoID = videoID
        webView.loadHTMLString(html, baseURL: Self.clientOrigin)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    private var html: String {
        """
        <!doctype html>
        <html>
          <head>
            <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
            <meta name="referrer" content="strict-origin-when-cross-origin">
            <style>
              html, body, iframe { width: 100%; height: 100%; margin: 0; padding: 0; border: 0; background: #000; overflow: hidden; }
            </style>
          </head>
          <body>
            <iframe
              src="https://www.youtube.com/embed/\(videoID)?playsinline=1&rel=0&origin=https%3A%2F%2Foverture.news"
              title="YouTube livestream"
              allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
              allowfullscreen
              referrerpolicy="strict-origin-when-cross-origin">
            </iframe>
          </body>
        </html>
        """
    }

    final class Coordinator {
        var loadedVideoID: String?
    }
}

private struct RocketLaunch: Identifiable, Hashable {
    let id: String
    let mission: String
    let shortTitle: String
    let vehicle: String
    let spacecraft: String?
    let provider: String
    let date: Date
    let datePrecision: String?
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

    var displayVehicle: String {
        switch vehicle.lowercased() {
        case "falcon 9 block 5":
            "Falcon 9"
        case "starship v3":
            "Starship"
        default:
            vehicle
        }
    }

    var coordinate: CLLocationCoordinate2D? {
        guard let latitude, let longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var dateDisplayText: String {
        Self.displayText(for: date, precision: datePrecision)
    }

    private static func displayText(for date: Date, precision: String?) -> String {
        let normalizedPrecision = precision?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard let normalizedPrecision else {
            return fullDayFormatter.string(from: date)
        }

        let year = utcCalendar.component(.year, from: date)

        switch normalizedPrecision {
        case "second", "minute", "hour":
            return fullDayFormatter.string(from: date)
        case "day":
            return dayOnlyFormatter.string(from: date)
        case "week":
            return "Week of \(dayOnlyFormatter.string(from: date))"
        case "month":
            return monthYearFormatter.string(from: date)
        case let precision where precision.hasPrefix("quarter "):
            return "Q\(precision.suffix(1)) \(year)"
        case "year half 1":
            return "Early \(year)"
        case "year half 2":
            return "Late \(year)"
        case "year":
            return String(year)
        case "fiscal year":
            return "FY \(year)"
        case "decade":
            return "\((year / 10) * 10)s"
        default:
            return fullDayFormatter.string(from: date)
        }
    }

    var showsCountdown: Bool {
        guard !isDateTBD else { return false }
        guard let normalizedPrecision else { return true }
        return ["second", "minute", "hour"].contains(normalizedPrecision)
    }

    private var isDateTBD: Bool {
        let normalizedStatus = status.lowercased()
        return normalizedStatus.contains("tbd") || normalizedStatus.contains("to be determined")
    }

    private var normalizedPrecision: String? {
        datePrecision?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    var isTerminal: Bool {
        let normalizedStatus = status.lowercased()
        return normalizedStatus.contains("failure")
            || normalizedStatus.contains("success")
            || normalizedStatus.contains("cancel")
    }

    var statusColor: Color {
        let normalizedStatus = status.lowercased()
        if normalizedStatus.contains("go") || normalizedStatus.contains("confirmed") {
            return .green
        }
        if normalizedStatus.contains("hold") || normalizedStatus.contains("tbd") {
            return .orange
        }
        return .white.opacity(0.72)
    }

    static var placeholderLaunches: [RocketLaunch] {
        let calendar = Calendar.current
        let firstDate = calendar.date(byAdding: .hour, value: 26, to: .now) ?? .now
        let secondDate = calendar.date(byAdding: .day, value: 5, to: .now) ?? .now

        return [
        RocketLaunch(
            id: "artemis-cargo-demo",
            mission: "Artemis Cargo Demo",
            shortTitle: "Artemis Cargo",
            vehicle: "SLS Block 1B",
            spacecraft: nil,
            provider: "NASA",
            date: firstDate,
            datePrecision: nil,
            launchWindow: Self.windowFormatter.string(from: firstDate),
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
            spacecraft: nil,
            provider: "SpaceX",
            date: secondDate,
            datePrecision: nil,
            launchWindow: Self.windowFormatter.string(from: secondDate),
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
}

private struct LaunchLibraryClient {
    private static let pageSize = 25

    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.waitsForConnectivity = true
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 30
        return URLSession(configuration: configuration)
    }()

    func upcomingLaunches(
        offset: Int = 0,
        forceRefresh: Bool = false
    ) async throws -> LaunchPage {
        if offset == 0,
           !forceRefresh,
           let cachedPage = await LaunchLibraryCache.shared.cachedPage {
            return cachedPage
        }

        var components = URLComponents(
            url: OvertureEnvironment.apiBaseURL.appending(path: "api/launches/upcoming"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(name: "limit", value: String(Self.pageSize)),
        ]
        if offset > 0 {
            components.queryItems?.append(URLQueryItem(name: "offset", value: String(offset)))
        }

        guard let url = components.url else {
            throw URLError(.badURL)
        }

        let cachePolicy: URLRequest.CachePolicy = forceRefresh
            ? .reloadIgnoringLocalCacheData
            : .useProtocolCachePolicy
        var request = URLRequest(url: url, cachePolicy: cachePolicy, timeoutInterval: 20)
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await Self.session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw LaunchLibraryError.httpStatus(httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload = try decoder.decode(LaunchLibraryResponse.self, from: data)
        let now = Date()
        let launches = payload.results
            .map(RocketLaunch.init(response:))
            .filter { $0.date > now && !$0.isTerminal }
            .sorted { $0.date < $1.date }
        guard !launches.isEmpty || payload.next != nil else {
            throw LaunchLibraryError.emptySchedule
        }

        let page = LaunchPage(
            launches: launches,
            nextOffset: payload.next.flatMap(Self.offset(from:))
        )
        if offset == 0 {
            await LaunchLibraryCache.shared.store(page)
        }
        return page
    }

    private static func offset(from url: URL) -> Int? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let value = components.queryItems?.first(where: { $0.name == "offset" })?.value else {
            return nil
        }
        return Int(value)
    }
}

private struct LaunchPage {
    let launches: [RocketLaunch]
    let nextOffset: Int?
}

private enum LaunchLibraryError: LocalizedError {
    case httpStatus(Int)
    case emptySchedule

    var errorDescription: String? {
        switch self {
        case .httpStatus(429):
            "The launch service is receiving too many requests. Please try again shortly."
        case .httpStatus:
            "The launch service returned an error. Pull to refresh or try again."
        case .emptySchedule:
            "No current launches were returned. Pull to refresh or try again."
        }
    }
}

private actor LaunchLibraryCache {
    static let shared = LaunchLibraryCache()

    private var page: LaunchPage?
    private var cachedAt: Date?
    private let timeToLive: TimeInterval = 30 * 60

    var cachedPage: LaunchPage? {
        guard let page, let cachedAt else { return nil }
        guard Date().timeIntervalSince(cachedAt) < timeToLive else { return nil }
        return page
    }

    func store(_ page: LaunchPage) {
        self.page = page
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
    let next: URL?
    let results: [LaunchLibraryLaunch]
}

private struct LaunchLibraryLaunch: Decodable {
    let id: String
    let name: String
    let status: LaunchStatus?
    let net: Date?
    let netPrecision: LaunchNetPrecision?
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
        case netPrecision = "net_precision"
        case image
        case launchServiceProvider = "launch_service_provider"
        case rocket
        case mission
        case pad
        case vidURLs = "vid_urls"
    }
}

private struct LaunchNetPrecision: Decodable {
    let name: String
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
    let spacecraftStage: [LaunchSpacecraftStage]?

    enum CodingKeys: String, CodingKey {
        case configuration
        case spacecraftStage = "spacecraft_stage"
    }
}

private struct LaunchSpacecraftStage: Decodable {
    let spacecraft: LaunchSpacecraft?
}

private struct LaunchSpacecraft: Decodable {
    let name: String?
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
    let type: LaunchVideoType?

    enum CodingKeys: String, CodingKey {
        case priority
        case title
        case featureImage = "feature_image"
        case url
        case live
        case type
    }

    var isOfficial: Bool {
        guard let typeName = type?.name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() else {
            return false
        }
        return typeName == "official" || typeName.hasPrefix("official ")
    }
}

private struct LaunchVideoType: Decodable {
    let name: String
}

private extension RocketLaunch {
    init(response: LaunchLibraryLaunch) {
        let launchDate = response.net ?? Date()
        let missionName = response.mission?.name ?? response.name
        let preferredVideo = response.vidURLs?
            .filter { $0.url != nil }
            .sorted { lhs, rhs in
                if lhs.isOfficial != rhs.isOfficial {
                    return lhs.isOfficial
                }
                if (lhs.live == true) != (rhs.live == true) {
                    return lhs.live == true
                }
                return (lhs.priority ?? Int.max) < (rhs.priority ?? Int.max)
            }
            .first

        self.init(
            id: response.id,
            mission: missionName,
            shortTitle: missionName.components(separatedBy: "|").last?.trimmingCharacters(in: .whitespacesAndNewlines) ?? missionName,
            vehicle: response.rocket?.configuration?.fullName ?? response.rocket?.configuration?.name ?? "Rocket",
            spacecraft: response.rocket?.spacecraftStage?
                .compactMap(\.spacecraft?.name)
                .first,
            provider: response.launchServiceProvider?.name ?? "Launch provider",
            date: launchDate,
            datePrecision: response.netPrecision?.name,
            launchWindow: Self.displayText(for: launchDate, precision: response.netPrecision?.name),
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

    private static let utcCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    private static let fullDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d, yyyy"
        return formatter
    }()

    private static let dayOnlyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    private static let monthYearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
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
    NavigationStack { LaunchesView() }
}
