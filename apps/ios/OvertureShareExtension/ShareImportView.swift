import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct ShareImportView: View {
    let extensionContext: NSExtensionContext?
    let cancel: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var state: ImportState = .submitting
    @State private var successStartedAt = Date.now

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

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
                    .foregroundStyle(.black)
                    .padding(.horizontal, 20)
                    .padding(.top, 28)
            }
        }
        .preferredColorScheme(.light)
        .task {
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
                    .tint(.black)
                Text("Submitting for review")
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .foregroundStyle(.black)
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
                    .tint(.black)
                    .padding(.top, 6)
            }
            .foregroundStyle(.black)
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
        try? await Task.sleep(for: .seconds(2))
        extensionContext?.completeRequest(returningItems: nil)
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

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { timeline in
            GeometryReader { proxy in
                let elapsed = max(0, timeline.date.timeIntervalSince(startedAt))
                let riseProgress = reduceMotion ? 1 : easeOutCubic(min(elapsed / 0.42, 1))
                let bubbleProgress = reduceMotion ? 1 : easeInOutCubic(
                    min(max((elapsed - 0.34) / 0.56, 0), 1)
                )
                let width = proxy.size.width
                let height = proxy.size.height
                let waveDiameter = width * 1.5
                let bubbleDiameter = min(width * 0.60, 244)
                let waveTop = mix(height + 40, height * 0.47, riseProgress)
                let waveCenter = CGPoint(x: width / 2, y: waveTop + waveDiameter / 2)
                let bubbleCenter = CGPoint(x: width / 2, y: height * 0.56)
                let lensCenter = mix(waveCenter, bubbleCenter, bubbleProgress)
                let diameter = mix(waveDiameter, bubbleDiameter, bubbleProgress)

                ZStack {
                    Color.white

                    Rectangle()
                        .fill(.white)
                        .colorEffect(
                            ShaderLibrary.liquidMetalBubble(
                                .float2(proxy.size),
                                .float2(lensCenter),
                                .float(Float(diameter / 2)),
                                .float(Float(reduceMotion ? 0 : elapsed)),
                                .float(reduceTransparency ? 0.28 : 1)
                            )
                        )

                    ZStack {
                        Text("Submitted")
                            .font(.system(.title3, design: .rounded, weight: .semibold))
                            .foregroundStyle(.black)
                            .position(bubbleCenter)
                    }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .mask {
                            Circle()
                                .frame(width: diameter, height: diameter)
                                .position(lensCenter)
                        }
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func mix(_ start: CGFloat, _ end: CGFloat, _ progress: Double) -> CGFloat {
        start + (end - start) * progress
    }

    private func mix(_ start: CGPoint, _ end: CGPoint, _ progress: Double) -> CGPoint {
        CGPoint(
            x: mix(start.x, end.x, progress),
            y: mix(start.y, end.y, progress)
        )
    }

    private func easeOutCubic(_ value: Double) -> Double {
        1 - pow(1 - value, 3)
    }

    private func easeInOutCubic(_ value: Double) -> Double {
        value < 0.5
            ? 4 * value * value * value
            : 1 - pow(-2 * value + 2, 3) / 2
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
