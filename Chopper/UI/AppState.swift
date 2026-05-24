import Foundation
import Observation

@Observable
final class AppState {
    var request = HTTPRequest()
    var response: HTTPResponse?
    var errorMessage: String?
    var isLoading = false

    /// Sends the current request and updates response / error state
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

    /// Re-parses query params out of the URL field. Keeps disabled params (they're not represented in the URL).
    func syncParamsFromURL() {
        // Drop empty-name items that show up while the user is typing (e.g. trailing `&`),
        // and normalize empty value ("") to nil so `?p` and `?p=` compare equal.
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

    /// Rewrites the URL field's query string to reflect the current enabled params.
    func syncURLFromParams() {
        let rebuilt = Self.rebuildURL(from: request.url, params: request.queryParams)
        if rebuilt != request.url {
            request.url = rebuilt
        }
    }

    static func parseQueryItems(from urlString: String) -> [URLQueryItem] {
        guard let components = URLComponents(string: urlString) else { return [] }
        return components.queryItems ?? []
    }

    static func rebuildURL(from urlString: String, params: [KeyValuePair]) -> String {
        guard var components = URLComponents(string: urlString) else { return urlString }
        let enabled = params.filter { $0.isEnabled && !$0.name.isEmpty }
        if enabled.isEmpty {
            components.queryItems = nil
        } else {
            // Empty value → no `=` in the URL (treat "" and absent value the same).
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
}
