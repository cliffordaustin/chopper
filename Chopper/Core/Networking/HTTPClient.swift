import Foundation

enum HTTPClientError: LocalizedError {
    case invalidURL
    case nonHTTPResponse
    case transport(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "The URL is invalid."
        case .nonHTTPResponse: return "The server didn't return an HTTP response."
        case .transport(let error): return error.localizedDescription
        }
    }
}

enum HTTPClient {
    /// Sends the given request and returns the response along with timing info.
    static func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        guard let url = buildURL(from: request) else {
            throw HTTPClientError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method.rawValue

        for header in request.headers where header.isEnabled && !header.name.isEmpty {
            urlRequest.setValue(header.value, forHTTPHeaderField: header.name)
        }

        if !request.body.isEmpty {
            urlRequest.httpBody = request.body.content.data(using: .utf8)
            // Auto-set Content-Type unless the user already provided one.
            let userSetContentType = request.headers.contains {
                $0.isEnabled && $0.name.lowercased() == "content-type"
            }
            if !userSetContentType, let contentType = request.body.type.contentType {
                urlRequest.setValue(contentType, forHTTPHeaderField: "Content-Type")
            }
        }

        let start = Date()
        let data: Data
        let urlResponse: URLResponse
        do {
            (data, urlResponse) = try await URLSession.shared.data(for: urlRequest)
        } catch {
            throw HTTPClientError.transport(error)
        }
        let duration = Date().timeIntervalSince(start)

        guard let httpResponse = urlResponse as? HTTPURLResponse else {
            throw HTTPClientError.nonHTTPResponse
        }

        // Normalize headers to [String: String]
        var headers: [String: String] = [:]
        for (key, value) in httpResponse.allHeaderFields {
            if let keyString = key as? String, let valueString = value as? String {
                headers[keyString] = valueString
            }
        }

        return HTTPResponse(
            statusCode: httpResponse.statusCode,
            headers: headers,
            body: data,
            duration: duration
        )
    }

    /// The URL field is kept in sync with `queryParams`
    /// so we just use the URL as-is here.
    static func buildURL(from request: HTTPRequest) -> URL? {
        URL(string: request.url)
    }
}
