import Foundation

/// Persists which tabs were open per workspace so they survive relaunch.
enum OpenTabsStore {
    struct Snapshot: Codable {
        var fileURLs: [String]
        var activeFileURL: String?
    }

    static func save(_ snapshot: Snapshot, for workspace: Workspace) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: key(for: workspace))
    }

    static func load(for workspace: Workspace) -> Snapshot? {
        guard
            let data = UserDefaults.standard.data(forKey: key(for: workspace)),
            let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data)
        else { return nil }
        return snapshot
    }

    private static func key(for workspace: Workspace) -> String {
        "OpenTabs:\(workspace.url.absoluteString)"
    }
}
