import Foundation

/// A node in the workspace tree — either a folder or a request file.
enum WorkspaceItem: Identifiable, Hashable {
    case folder(url: URL, children: [WorkspaceItem])
    case request(url: URL)

    var id: URL { url }

    var url: URL {
        switch self {
        case .folder(let url, _), .request(let url): return url
        }
    }

    var name: String {
        switch self {
        case .folder(let url, _):
            return url.lastPathComponent
        case .request(let url):
            return url.deletingPathExtension().deletingPathExtension().lastPathComponent
        }
    }

    /// Returns `nil` for request files so `List`'s `children:` API treats them
    /// as leaves and doesn't show a disclosure triangle.
    var children: [WorkspaceItem]? {
        switch self {
        case .folder(_, let children): return children
        case .request: return nil
        }
    }

    var isRequest: Bool {
        if case .request = self { return true }
        return false
    }
}
