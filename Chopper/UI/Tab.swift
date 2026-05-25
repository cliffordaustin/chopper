import Foundation
import Observation

@MainActor
@Observable
final class Tab: Identifiable {
    nonisolated let id = UUID()

    var fileURL: URL
    var request: HTTPRequest
    var response: HTTPResponse?
    var errorMessage: String?
    var isLoading = false

    private var autosaveTask: Task<Void, Never>?

    var displayName: String {
        fileURL.deletingPathExtension().deletingPathExtension().lastPathComponent
    }

    init(fileURL: URL, request: HTTPRequest = HTTPRequest()) {
        self.fileURL = fileURL
        self.request = request
    }

    // MARK: - Send

    func send() async {
        guard !isLoading else { return }
        guard request.isSendable else {
            errorMessage = "Please enter a valid URL (including http:// or https://)."
            return
        }
        isLoading = true
        errorMessage = nil
        response = nil
        do {
            response = try await HTTPClient.send(request)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - URL ↔ params sync

    func syncParamsFromURL() {
        let parsedItems = Self.parseQueryItems(from: request.url)
            .filter { !$0.name.isEmpty }
            .map { URLQueryItem(name: $0.name, value: Self.normalize($0.value)) }
        let currentEnabledItems = request.queryParams
            .filter { $0.isEnabled && !$0.name.isEmpty }
            .map { URLQueryItem(name: $0.name, value: Self.normalize($0.value)) }

        if parsedItems == currentEnabledItems { return }

        let disabled = request.queryParams.filter { !$0.isEnabled && !$0.isBlank }
        var newParams = parsedItems.map { item -> KeyValuePair in
            var p = KeyValuePair()
            p.name = item.name
            p.value = item.value ?? ""
            return p
        }
        newParams.append(contentsOf: disabled)
        request.queryParams = newParams
    }

    func syncURLFromParams() {
        let rebuilt = Self.rebuildURL(from: request.url, params: request.queryParams)
        if rebuilt != request.url { request.url = rebuilt }
    }

    private static func parseQueryItems(from urlString: String) -> [URLQueryItem] {
        guard let components = URLComponents(string: urlString) else { return [] }
        return components.queryItems ?? []
    }

    private static func rebuildURL(from urlString: String, params: [KeyValuePair]) -> String {
        guard var components = URLComponents(string: urlString) else { return urlString }
        let enabled = params.filter { $0.isEnabled && !$0.name.isEmpty }
        if enabled.isEmpty {
            components.queryItems = nil
        } else {
            components.queryItems = enabled.map {
                URLQueryItem(name: $0.name, value: normalize($0.value))
            }
        }
        return components.string ?? urlString
    }

    private static func normalize(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        return value
    }

    // MARK: - Autosave

    /// Debounces a write of `request` to `fileURL`.
    func scheduleAutosave() {
        autosaveTask?.cancel()
        autosaveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(1500))
            guard let self, !Task.isCancelled else { return }
            try? RequestStore.write(self.request, to: self.fileURL)
        }
    }

    /// Cancels the debounce and writes immediately.
    func flushAutosave() {
        autosaveTask?.cancel()
        autosaveTask = nil
        try? RequestStore.write(request, to: fileURL)
    }

    /// Cancels the debounce without writing. Use before deleting the file.
    func cancelAutosave() {
        autosaveTask?.cancel()
        autosaveTask = nil
    }
}
