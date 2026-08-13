import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct ShareImportView: View {
    let extensionContext: NSExtensionContext?
    let cancel: () -> Void
    private let previewsSuccess: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme
    @State private var state: ImportState
    @State private var successStartedAt: Date

    init(
        extensionContext: NSExtensionContext?,
        cancel: @escaping () -> Void,
        previewsSuccess: Bool = false
    ) {
        self.extensionContext = extensionContext
        self.cancel = cancel
        self.previewsSuccess = previewsSuccess
        _state = State(initialValue: previewsSuccess ? .success : .submitting)
        _successStartedAt = State(initialValue: .now)
    }

    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground).ignoresSafeArea()

            if case .success = state {
                ZStack {
                    LiquidGlassSuccessWave(
                        startedAt: successStartedAt,
                        reduceMotion: reduceMotion,
                        reduceTransparency: reduceTransparency
                    )
                    .ignoresSafeArea()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.opacity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Article submitted for review")
            } else {
                statusContent
            }
        }
        .overlay(alignment: .topLeading) {
            if case .success = state {
                EmptyView()
            } else {
                Button("Cancel", action: cancel)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 20)
                    .padding(.top, 28)
            }
        }
        .task {
            guard !previewsSuccess else { return }
            await importArticle()
        }
    }

    @ViewBuilder
    private var statusContent: some View {
        switch state {
        case .submitting:
            VStack(spacing: 18) {
                ProgressView()
                    .controlSize(.regular)
                    .tint(.primary)
                Text("Submitting for review")
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .foregroundStyle(.primary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Submitting for review")

        case .success:
            EmptyView()

        case .failure(let message):
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.circle")
                    .font(.system(size: 34, weight: .medium))
                Text("Couldn’t submit")
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
                Button("Close", action: cancel)
                    .buttonStyle(.borderedProminent)
                    .tint(colorScheme == .dark ? .white : .black)
                    .padding(.top, 6)
            }
            .foregroundStyle(.primary)
            .padding(28)
        }
    }

    @MainActor
    private func showSuccess() async {
        SuccessHaptics.prepare()
        successStartedAt = .now
        withAnimation(.easeOut(duration: reduceMotion ? 0.18 : 0.28)) {
            state = .success
        }
        await SuccessHaptics.play(reduced: reduceMotion)
    }

    private func importArticle() async {
        guard let token = AuthTokenStore().read() else {
            state = .failure("Open Overture and sign in with an editor account, then try sharing again.")
            return
        }

        do {
            let sourceURL = try await sharedURL()
            var request = URLRequest(url: OvertureEnvironment.apiBaseURL.appending(path: "api/editor/import-article"))
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(ImportRequest(sourceURL: sourceURL))
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let response = response as? HTTPURLResponse else { throw ImportError.invalidResponse }
            guard (200..<300).contains(response.statusCode) else {
                let message = (try? JSONDecoder().decode(ErrorResponse.self, from: data).message)
                throw ImportError.server(message ?? "Overture returned status \(response.statusCode).")
            }
            await showSuccess()
        } catch {
            await MainActor.run {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                state = .failure(error.localizedDescription)
            }
        }
    }

    private func sharedURL() async throws -> URL {
        let providers = extensionContext?.inputItems
            .compactMap { $0 as? NSExtensionItem }
            .flatMap { $0.attachments ?? [] } ?? []

        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            let item = try await provider.loadItem(forTypeIdentifier: UTType.url.identifier)
            if let url = item as? URL { return url }
            if let value = item as? String, let url = URL(string: value) { return url }
        }
        throw ImportError.missingURL
    }
}

private struct LiquidGlassSuccessWave: View {
    let startedAt: Date
    let reduceMotion: Bool
    let reduceTransparency: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { timeline in
            GeometryReader { proxy in
                let elapsed = max(0, timeline.date.timeIntervalSince(startedAt))
                let riseProgress = reduceMotion ? 1 : easeOutCubic(min(elapsed / 0.62, 1))
                let labelProgress = reduceMotion ? 1 : smoothstep(0.46, 0.76, elapsed)
                let width = proxy.size.width
                let height = proxy.size.height

                ZStack {
                    Color(uiColor: .systemBackground)

                    Rectangle()
                        .fill(.white)
                        .colorEffect(
                            ShaderLibrary.rainbowWaveField(
                                .float2(proxy.size),
                                .float(Float(reduceMotion ? 0 : elapsed)),
                                .float(Float(riseProgress)),
                                .float(reduceTransparency ? 0.45 : 1),
                                .float(colorScheme == .dark ? 1 : 0)
                            )
                        )

                    submittedBadge(reduceTransparency: reduceTransparency)
                        .position(x: width / 2, y: height * 0.40)
                        .opacity(labelProgress)
                        .scaleEffect(0.94 + labelProgress * 0.06)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func easeOutCubic(_ value: Double) -> Double {
        1 - pow(1 - value, 3)
    }

    private func smoothstep(_ edge0: Double, _ edge1: Double, _ value: Double) -> Double {
        let progress = min(max((value - edge0) / (edge1 - edge0), 0), 1)
        return progress * progress * (3 - 2 * progress)
    }

    @ViewBuilder
    private func submittedBadge(reduceTransparency: Bool) -> some View {
        let label = Text("Submitted")
            .font(.system(.title3, design: .rounded, weight: .semibold))
            .foregroundStyle(.primary)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)

        if reduceTransparency {
            label
                .background(Color(uiColor: .secondarySystemBackground), in: Capsule())
                .overlay(Capsule().stroke(.primary.opacity(0.08), lineWidth: 1))
                .shadow(color: .black.opacity(0.08), radius: 18, y: 8)
        } else {
            label
                .glassEffect(.clear, in: .capsule)
        }
    }
}

@MainActor
private enum SuccessHaptics {
    private static let notification = UINotificationFeedbackGenerator()
    private static let softImpact = UIImpactFeedbackGenerator(style: .soft)
    private static let lightImpact = UIImpactFeedbackGenerator(style: .light)

    static func prepare() {
        notification.prepare()
        softImpact.prepare()
        lightImpact.prepare()
    }

    static func play(reduced: Bool) async {
        notification.notificationOccurred(.success)
        guard !reduced else { return }
        try? await Task.sleep(for: .milliseconds(110))
        softImpact.impactOccurred(intensity: 0.72)
        try? await Task.sleep(for: .milliseconds(120))
        lightImpact.impactOccurred(intensity: 0.48)
    }
}

private struct ImportRequest: Encodable { let sourceURL: URL }
private struct ErrorResponse: Decodable { let message: String }

private enum ImportError: LocalizedError {
    case invalidResponse
    case missingURL
    case server(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: "Overture returned an invalid response."
        case .missingURL: "This share does not contain an article URL."
        case .server(let message): message
        }
    }
}

private enum ImportState {
    case submitting
    case success
    case failure(String)
}
