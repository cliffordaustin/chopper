import Foundation

enum HTTPMethod: String, CaseIterable, Identifiable, Codable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
    case patch = "PATCH"

    var id: String { rawValue }
}
