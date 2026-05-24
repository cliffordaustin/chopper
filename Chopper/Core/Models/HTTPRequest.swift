import Foundation

struct HTTPRequest: Codable, Equatable {
    var method: HTTPMethod = .get
    var url: String = ""
    var headers: [KeyValuePair] = []
    var queryParams: [KeyValuePair] = []

    /// Whether this request looks ready to send.
    var isSendable: Bool {
        guard let parsed = URL(string: url), parsed.scheme != nil else { return false }
        return true
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
