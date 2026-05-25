import Foundation

/// Persists the user's chosen workspace folder across launches via a
/// security-scoped bookmark. Required by the sandbox: a raw URL doesn't
/// grant the next process access to user-selected folders outside the
/// container, but a bookmark does.
enum WorkspaceBookmark {
    private static let key = "WorkspaceBookmark"

    static func save(_ url: URL) throws {
        let data = try url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        UserDefaults.standard.set(data, forKey: key)
    }

    /// Resolves the saved bookmark and starts security-scoped access.
    /// Returns nil if no bookmark, or if resolving/access fails.
    /// Note: we never call `stopAccessingSecurityScopedResource`-access is
    /// held for the lifetime of the process and released on exit.
    static func resolve() -> URL? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        var isStale = false
        guard
            let url = try? URL(
                resolvingBookmarkData: data,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ),
            url.startAccessingSecurityScopedResource()
        else { return nil }

        if isStale {
            try? save(url)
        }
        return url
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
