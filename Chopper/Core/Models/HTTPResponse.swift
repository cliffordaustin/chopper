import Foundation

struct HTTPResponse: Equatable {
    let statusCode: Int
    let headers: [String: String]
    let body: Data
    let duration: TimeInterval

    /// Best-effort UTF-8 string representation of the body.
    var bodyString: String? {
        String(data: body, encoding: .utf8)
    }

    /// Returns the body as pretty-printed JSON, or nil if it isn't valid JSON.
    var prettyJSON: String? {
        guard
            let object = try? JSONSerialization.jsonObject(with: body, options: [.fragmentsAllowed]),
            let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys, .fragmentsAllowed]),
            let string = String(data: data, encoding: .utf8)
        else {
            return nil
        }
        return string
    }

    /// JSON-formatted body if valid, otherwise raw body string.
    var displayBody: String {
        prettyJSON ?? bodyString ?? "<binary data, \(body.count) bytes>"
    }

    /// Convenience for showing status code + reason.
    var statusDescription: String {
        "\(statusCode) \(HTTPURLResponse.localizedString(forStatusCode: statusCode).capitalized)"
    }
}
