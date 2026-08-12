import AuthenticationServices
import SwiftUI

struct HomeView: View {
    @Environment(NewsStore.self) private var store
    @State private var isProfilePresented = false

    var body: some View {
        configuredHome
            .background(OvertureTheme.ink)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $isProfilePresented) {
                ProfileSettingsSheet()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.hidden)
                    .interactiveDismissDisabled(false)
            }
            .task {
                await store.loadPublication()
            }
    }

    @ViewBuilder
    private var configuredHome: some View {
        if #available(iOS 27.0, *) {
            feed(editionTopPadding: 130)
                .ignoresSafeArea(edges: .top)
                .safeAreaBar(edge: .top, spacing: 0) {
                    HomeHeader(showProfile: showProfile, showsFallbackBackground: true)
                }
                .scrollEdgeEffectStyle(.soft, for: .top)
        } else if #available(iOS 26.0, *) {
            feed(editionTopPadding: 130)
                .ignoresSafeArea(edges: .top)
                .safeAreaBar(edge: .top, spacing: 0) {
                    HomeHeader(showProfile: showProfile)
                }
                .scrollEdgeEffectStyle(.soft, for: .top)
        } else {
            ZStack(alignment: .top) {
                feed(editionTopPadding: 130)
                    .ignoresSafeArea(edges: .top)

                HomeHeader(showProfile: showProfile, showsFallbackBackground: true)
            }
        }
    }

    private func feed(editionTopPadding: CGFloat) -> some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if let leadStory = store.stories.first {
                    LeadStoryView(
                        story: leadStory,
                        editionTopPadding: editionTopPadding
                    )

                    ForEach(store.stories.dropFirst()) { story in
                        StoryRow(story: story)
                            .padding(.horizontal, 24)
                    }
                }

                Text("Three things worth knowing today.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 30)
            }
        }
    }

    private func showProfile() {
        isProfilePresented = true
    }
}

private struct HomeHeader: View {
    @Environment(AuthenticationSession.self) private var authentication
    let showProfile: () -> Void
    var showsFallbackBackground = false

    var body: some View {
        HStack(alignment: .center) {
            Text("Overture")
                .font(OvertureTheme.editorial(52))
                .tracking(-2)

            Spacer()

            profileButton
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .foregroundStyle(.white)
        .background(alignment: .top) {
            if showsFallbackBackground {
                fallbackBackground
            }
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var profileButton: some View {
        if #available(iOS 26.0, *) {
            Button(action: showProfile) {
                profileLabel
                    .glassEffect(.regular.interactive(), in: .circle)
            }
            .buttonStyle(.plain)
            .frame(width: 44, height: 44)
        } else {
            Button(action: showProfile) {
                profileLabel
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(Circle().stroke(.white.opacity(0.28)))
            }
            .buttonStyle(.plain)
            .frame(width: 44, height: 44)
        }
    }

    @ViewBuilder
    private var profileLabel: some View {
        Group {
            if let initials = authentication.userInitials {
                Text(initials)
                    .font(.system(size: 18, weight: .semibold))
            } else {
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 23, weight: .medium))
            }
        }
            .frame(width: 42, height: 42)
            .contentShape(Circle())
            .accessibilityLabel("Profile and settings")
            .accessibilityIdentifier("profile-button")
    }

    private var headerFade: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: .black.opacity(0.80), location: 0),
                .init(color: .black.opacity(0.80), location: 0.48),
                .init(color: .black.opacity(0.56), location: 0.68),
                .init(color: .black.opacity(0.22), location: 0.84),
                .init(color: .clear, location: 1),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var blurFade: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: .black.opacity(0.20), location: 0),
                .init(color: .black.opacity(0.20), location: 0.48),
                .init(color: .black.opacity(0.12), location: 0.68),
                .init(color: .black.opacity(0.05), location: 0.84),
                .init(color: .clear, location: 1),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var fallbackBackground: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .mask(blurFade)

            Rectangle()
                .fill(OvertureTheme.ink)
                .mask(headerFade)
        }
        .frame(height: 170)
        .ignoresSafeArea(edges: .top)
        .allowsHitTesting(false)
    }
}

private struct LeadStoryView: View {
    @Environment(NewsStore.self) private var store
    let story: Story
    let editionTopPadding: CGFloat

    var body: some View {
        NavigationLink(value: story) {
            ZStack(alignment: .bottomLeading) {
                StoryImage(story: story, fallbackName: "QuietFlightPortrait")
                    .frame(height: 720)
                    .clipped()

                LinearGradient(
                    colors: [.clear, OvertureTheme.ink.opacity(0.12), OvertureTheme.ink],
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Spacer()
                        EditionMenu()
                    }
                    .padding(.top, editionTopPadding)

                    Spacer()

                    Text(story.title)
                        .font(OvertureTheme.editorial(51))
                        .tracking(-1.8)
                        .lineSpacing(-2)

                    Text(story.deck)
                        .font(.system(size: 18))
                        .foregroundStyle(.white.opacity(0.82))
                        .lineSpacing(5)
                        .padding(.top, 18)

                    Text("\(story.readTime)   ·   Save")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.72))
                        .padding(.top, 22)
                        .padding(.bottom, 30)
                }
                .padding(.horizontal, 24)
                .foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open \(story.title)")
    }
}

private struct ProfileSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(NewsStore.self) private var store
    @Environment(AuthenticationSession.self) private var authentication

    var body: some View {
        @Bindable var store = store

        NavigationStack {
            Form {
                Section {
                    if authentication.isAuthenticated {
                        if let userEmail = authentication.userEmail {
                            LabeledContent("Signed in as", value: userEmail)
                        } else {
                            Label("Signed in with Apple", systemImage: "checkmark.circle.fill")
                        }

                        Button("Sign out", role: .destructive) {
                            Task {
                                await authentication.signOut()
                            }
                        }
                    } else {
                        SignInWithAppleButton(.continue) { request in
                            authentication.prepareAppleRequest(request)
                        } onCompletion: { result in
                            authentication.completeAppleAuthorization(result)
                        }
                        .signInWithAppleButtonStyle(.black)
                        .frame(height: 48)
                        .disabled(authentication.isWorking)

                        if authentication.isWorking {
                            ProgressView("Signing in…")
                        }

                        if let errorMessage = authentication.errorMessage {
                            Text(errorMessage)
                                .foregroundStyle(.red)
                        }
                    }
                } header: {
                    Text("Account")
                } footer: {
                    Text("Sync saved stories, editions, and preferences across devices.")
                }

                Section("Notifications") {
                    Toggle("Important stories", isOn: $store.alertsEnabled)
                    Toggle("Morning edition", isOn: $store.morningEditionNotifications)
                        .disabled(!store.alertsEnabled)
                    Toggle("Product updates", isOn: $store.productUpdateNotifications)
                        .disabled(!store.alertsEnabled)
                }

                Section("Reading") {
                    Toggle("Download saved stories", isOn: $store.downloadSavedStories)
                    Toggle("Open links in Overture", isOn: $store.openLinksInApp)
                }

                Section {
                    Button("Manage subscription") {}
                    Button("Privacy") {}
                    NavigationLink("Legal & Attributions") {
                        ModelAttributionsView()
                    }
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Close profile")
                    .accessibilityIdentifier("close-profile-button")
                }
            }
            .tint(OvertureTheme.cobalt)
        }
    }
}

private struct ModelAttributionsView: View {
    private static let creativeCommonsURL = URL(string: "https://creativecommons.org/licenses/by/4.0/")!

    private let credits = [
        ModelCredit(
            name: "Falcon 9 Block 5",
            creator: "AllThingsSpace",
            sourceURL: URL(string: "https://sketchfab.com/3d-models/spacex-falcon-9-block-5-61067a8b341c4b4b96053d5fa607f232")!
        ),
        ModelCredit(
            name: "Falcon 9 Crew Dragon",
            creator: "KUBAHA",
            sourceURL: URL(string: "https://sketchfab.com/3d-models/falcon-9-crew-dragon-7cbafced513f4bec9d0a956c94a3bfd1")!
        ),
        ModelCredit(
            name: "Falcon Heavy",
            creator: "SunnyChen753 / SW fan",
            sourceURL: URL(string: "https://sketchfab.com/3d-models/spacex-falcon-heavy-2f11453207944cedba00e2c6c1aa1269")!
        ),
        ModelCredit(
            name: "Starship Block 3",
            creator: "Clarence365",
            sourceURL: URL(string: "https://sketchfab.com/3d-models/spacex-starship-block-3-6f6c6f88a3eb4b4d822fdca66733fbb2")!
        ),
        ModelCredit(
            name: "Firefly Alpha",
            creator: "Clarence365",
            sourceURL: URL(string: "https://sketchfab.com/3d-models/firefly-alpha-rocket-9ae27271818d4a4dbe8290cadb044a11")!
        ),
        ModelCredit(
            name: "Electron",
            creator: "Stanley Creative",
            sourceURL: URL(string: "https://sketchfab.com/3d-models/electron-rocket-lab-0376dfab27574a909cb8714841379894")!
        ),
    ]

    var body: some View {
        Form {
            Section {
                Text("Rocket models are used under Creative Commons Attribution 4.0. Overture has adjusted model scale, materials, and textures for in-app presentation.")
                    .foregroundStyle(.secondary)
            }

            ForEach(credits) { credit in
                Section(credit.name) {
                    LabeledContent("Creator", value: credit.creator)

                    Link(destination: credit.sourceURL) {
                        Label("View source model", systemImage: "arrow.up.right.square")
                    }

                    Link(destination: Self.creativeCommonsURL) {
                        Label("CC BY 4.0 license", systemImage: "doc.text")
                    }
                }
            }
        }
        .navigationTitle("Attributions")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ModelCredit: Identifiable {
    let name: String
    let creator: String
    let sourceURL: URL

    var id: String { name }
}

private struct EditionMenu: View {
    @Environment(NewsStore.self) private var store

    var body: some View {
        @Bindable var store = store

        Menu {
            Picker("Edition", selection: $store.edition) {
                ForEach(Edition.allCases) { edition in
                    Text(edition.title).tag(edition)
                }
            }
        } label: {
            Label(store.editionTitle, systemImage: "chevron.down")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .frame(height: 44)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.roundedRectangle(radius: 14))
        .tint(OvertureTheme.ink.opacity(0.78))
        .accessibilityIdentifier("edition-menu")
    }
}

private struct StoryRow: View {
    let story: Story

    var body: some View {
        NavigationLink(value: story) {
            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(story.title)
                        .font(OvertureTheme.editorial(30))
                        .tracking(-0.7)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(story.deck)
                        .font(.subheadline)
                        .foregroundStyle(OvertureTheme.muted)
                        .lineSpacing(4)
                        .lineLimit(4)
                        .padding(.top, 16)

                    Spacer(minLength: 12)

                    Text("\(story.readTime)  ·  Save")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(OvertureTheme.muted)
                }

                StoryImage(story: story)
                    .frame(width: 158, height: 172)
                    .clipShape(.rect(cornerRadius: 14))
            }
            .frame(minHeight: 210)
            .padding(.vertical, 24)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(OvertureTheme.divider)
                    .frame(height: 0.5)
            }
            .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open \(story.title)")
    }
}

struct StoryImage: View {
    let story: Story
    var fallbackName: String? = nil

    var body: some View {
        if let imageURL = story.imageURL {
            AsyncImage(url: imageURL) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    fallbackImage
                }
            }
        } else {
            fallbackImage
        }
    }

    private var fallbackImage: some View {
        Image(fallbackName ?? story.imageName)
            .resizable()
            .scaledToFill()
    }
}

#Preview {
    NavigationStack { HomeView() }
        .environment(NewsStore())
}
