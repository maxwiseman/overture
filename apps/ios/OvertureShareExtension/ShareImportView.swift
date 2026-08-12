import SwiftUI
import UniformTypeIdentifiers

struct ShareImportView: View {
    let extensionContext: NSExtensionContext?
    let cancel: () -> Void

    @State private var state: ImportState = .loading

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Image(systemName: state.symbol)
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(state.color)

                Text(state.title)
                    .font(.title2.bold())

                Text(state.detail)
                    .foregroundStyle(.secondary)

                if case .loading = state {
                    ProgressView()
                }

                Spacer()

                if state.isFinished {
                    Button("Done") { extensionContext?.completeRequest(returningItems: nil) }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(24)
            .navigationTitle("Save to Overture")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: cancel)
                }
            }
        }
        .task { await importArticle() }
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
            state = .success
        } catch {
            state = .failure(error.localizedDescription)
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
    case loading
    case success
    case failure(String)

    var title: String {
        switch self {
        case .loading: "Creating an editorial draft…"
        case .success: "Saved for review"
        case .failure: "Couldn’t save this article"
        }
    }

    var detail: String {
        switch self {
        case .loading: "Overture is extracting the source and starting a reviewable AI draft."
        case .success: "The draft and its shorter versions are being generated in Payload. Nothing is published automatically."
        case .failure(let message): message
        }
    }

    var symbol: String {
        switch self {
        case .loading: "newspaper"
        case .success: "checkmark.circle.fill"
        case .failure: "exclamationmark.triangle.fill"
        }
    }

    var color: Color {
        switch self {
        case .loading: .accentColor
        case .success: .green
        case .failure: .orange
        }
    }

    var isFinished: Bool {
        if case .loading = self { false } else { true }
    }
}
