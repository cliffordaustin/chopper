import Foundation

struct HTTPRequest: Codable, Equatable {
    var method: HTTPMethod = .get
    var url: String = ""
    var headers: [KeyValuePair] = []
    var queryParams: [KeyValuePair] = []
    var body: HTTPBody = HTTPBody()

    /// Whether this request looks ready to send.
    var isSendable: Bool {
        guard let parsed = URL(string: url), parsed.scheme != nil else { return false }
        return true
    }
}

struct HTTPBody: Codable, Equatable {
    var type: HTTPBodyType = .none
    var content: String = ""

    var isEmpty: Bool {
        type == .none || content.isEmpty
    }
}

enum HTTPBodyType: String, CaseIterable, Identifiable, Codable {
    case none = "None"
    case text = "Text"
    case json = "JSON"

    var id: String { rawValue }

    /// Content-Type value to send automatically (unless the user set their own).
    var contentType: String? {
        switch self {
        case .none: return nil
        case .text: return "text/plain"
        case .json: return "application/json"
        }
    }
}

struct KeyValuePair: Codable, Equatable, Identifiable {
    var id = UUID()
    var name: String = ""
    var value: String = ""
    var isEnabled: Bool = true

    var isBlank: Bool {
        name.trimmingCharacters(in: .whitespaces).isEmpty &&
        value.trimmingCharacters(in: .whitespaces).isEmpty
    }
}
