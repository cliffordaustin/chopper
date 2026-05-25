import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class AppState {
    private(set) var workspace: Workspace
    private(set) var workspaceItems: [WorkspaceItem] = []

    var tabs: [Tab] = []
    var activeTabID: Tab.ID?

    private var watcher: WorkspaceWatcher?

    var activeTab: Tab? {
        guard let id = activeTabID else { return nil }
        return tabs.first { $0.id == id }
    }

    init(workspace: Workspace? = nil) {
        let resolved: Workspace = workspace
            ?? WorkspaceBookmark.resolve().map(Workspace.init(url:))
            ?? .default
        self.workspace = resolved
        try? resolved.ensureExists()
        self.workspaceItems = resolved.scan()
        defer { startWatching() }

        // Try restoring tabs from the last session in this workspace.
        if let snapshot = OpenTabsStore.load(for: resolved) {
            let restored = snapshot.fileURLs
                .compactMap { URL(string: $0) }
                .filter { FileManager.default.fileExists(atPath: $0.path) }
                .compactMap { url -> Tab? in
                    guard let req = try? RequestStore.read(from: url) else { return nil }
                    return Tab(fileURL: url, request: req)
                }
            if !restored.isEmpty {
                self.tabs = restored
                if let activeStr = snapshot.activeFileURL,
                   let active = restored.first(where: { $0.fileURL.absoluteString == activeStr }) {
                    self.activeTabID = active.id
                } else {
                    self.activeTabID = restored.first?.id
                }
                return
            }
        }

        // Fresh launch or empty snapshot: open the first request, or create one.
        if let first = Self.firstRequestURL(in: workspaceItems),
           let loaded = try? RequestStore.read(from: first) {
            let tab = Tab(fileURL: first, request: loaded)
            self.tabs = [tab]
            self.activeTabID = tab.id
        } else if let url = try? resolved.createNewRequest() {
            let tab = Tab(fileURL: url, request: HTTPRequest())
            self.tabs = [tab]
            self.activeTabID = tab.id
            self.workspaceItems = resolved.scan()
        }
    }

    private func saveTabState() {
        let snapshot = OpenTabsStore.Snapshot(
            fileURLs: tabs.map { $0.fileURL.absoluteString },
            activeFileURL: activeTab?.fileURL.absoluteString
        )
        OpenTabsStore.save(snapshot, for: workspace)
    }

    private func startWatching() {
        watcher?.stop()
        let w = WorkspaceWatcher(url: workspace.url) { [weak self] in
            self?.handleWorkspaceChange()
        }
        w.start()
        watcher = w
    }

    /// Called when the file-system watcher detects an external change.
    /// Refreshes the sidebar and closes any tabs whose backing file is gone.
    private func handleWorkspaceChange() {
        refreshWorkspace()

        let missing = tabs.filter { !FileManager.default.fileExists(atPath: $0.fileURL.path) }
        for tab in missing {
            tab.cancelAutosave()
            if let idx = tabs.firstIndex(where: { $0.id == tab.id }) {
                tabs.remove(at: idx)
                if activeTabID == tab.id {
                    if idx < tabs.count {
                        activeTabID = tabs[idx].id
                    } else if idx > 0 {
                        activeTabID = tabs[idx - 1].id
                    } else {
                        activeTabID = nil
                    }
                }
            }
        }
        if !missing.isEmpty { saveTabState() }
    }

    /// Set the active tab and persist the change. Use this instead of writing
    /// to `activeTabID` directly so we don't lose persistence on UI taps.
    func setActiveTab(_ id: Tab.ID?) {
        activeTabID = id
        saveTabState()
    }

    // MARK: - Workspace refresh

    func refreshWorkspace() {
        workspaceItems = workspace.scan()
    }

    // MARK: - Tab management

    /// Activates the tab for `url` if one exists; otherwise opens a new tab.
    func openTab(for url: URL) {
        if let existing = tabs.first(where: { $0.fileURL == url }) {
            activeTabID = existing.id
            saveTabState()
            return
        }
        do {
            let loaded = try RequestStore.read(from: url)
            let tab = Tab(fileURL: url, request: loaded)
            tabs.append(tab)
            activeTabID = tab.id
            saveTabState()
        } catch {
            NSAlert(error: error).runModal()
        }
    }

    func closeTab(_ id: Tab.ID) {
        guard let idx = tabs.firstIndex(where: { $0.id == id }) else { return }
        let tab = tabs[idx]
        tab.flushAutosave()
        tabs.remove(at: idx)

        if activeTabID == id {
            if idx < tabs.count {
                activeTabID = tabs[idx].id
            } else if idx > 0 {
                activeTabID = tabs[idx - 1].id
            } else {
                activeTabID = nil
            }
        }
        saveTabState()
    }

    func closeActiveTab() {
        if let id = activeTabID { closeTab(id) }
    }

    // MARK: - File ops

    func newRequest(in parent: URL? = nil) {
        guard let url = try? workspace.createNewRequest(in: parent) else { return }
        let tab = Tab(fileURL: url, request: HTTPRequest())
        tabs.append(tab)
        activeTabID = tab.id
        refreshWorkspace()
        saveTabState()
    }

    func createFolder(in parent: URL? = nil) {
        _ = try? workspace.createFolder(in: parent)
        refreshWorkspace()
    }

    func renameItem(at url: URL, to newName: String) throws {
        let newURL = try workspace.rename(url, to: newName)
        let oldPath = url.path
        for tab in tabs {
            let p = tab.fileURL.path
            if p == oldPath {
                tab.fileURL = newURL
            } else if p.hasPrefix(oldPath + "/") {
                let suffix = String(p.dropFirst(oldPath.count))
                tab.fileURL = URL(fileURLWithPath: newURL.path + suffix)
            }
        }
        refreshWorkspace()
        saveTabState()
    }

    func deleteItem(at url: URL) throws {
        let deletedPath = url.path
        // Tabs whose files are being deleted — cancel autosave first so the
        // debounced write can't resurrect the file mid-delete.
        let tabsToClose = tabs.filter {
            let p = $0.fileURL.path
            return p == deletedPath || p.hasPrefix(deletedPath + "/")
        }
        for t in tabsToClose { t.cancelAutosave() }

        try workspace.delete(url)

        for t in tabsToClose {
            if let idx = tabs.firstIndex(where: { $0.id == t.id }) {
                tabs.remove(at: idx)
                if activeTabID == t.id {
                    if idx < tabs.count {
                        activeTabID = tabs[idx].id
                    } else if idx > 0 {
                        activeTabID = tabs[idx - 1].id
                    } else {
                        activeTabID = nil
                    }
                }
            }
        }

        refreshWorkspace()
        saveTabState()
    }

    /// Switches the workspace and reloads. Persists selection via a
    /// security-scoped bookmark. Pass `nil` to revert to the default.
    func switchWorkspace(to url: URL?) throws {
        for t in tabs { t.flushAutosave() }
        tabs.removeAll()
        activeTabID = nil

        if let url {
            try WorkspaceBookmark.save(url)
            workspace = Workspace(url: url)
        } else {
            WorkspaceBookmark.clear()
            workspace = .default
        }
        try workspace.ensureExists()
        refreshWorkspace()
        startWatching()

        // Restore the new workspace's saved tabs if any, else open its first request.
        if let snapshot = OpenTabsStore.load(for: workspace) {
            let restored = snapshot.fileURLs
                .compactMap { URL(string: $0) }
                .filter { FileManager.default.fileExists(atPath: $0.path) }
                .compactMap { url -> Tab? in
                    guard let req = try? RequestStore.read(from: url) else { return nil }
                    return Tab(fileURL: url, request: req)
                }
            if !restored.isEmpty {
                tabs = restored
                if let activeStr = snapshot.activeFileURL,
                   let active = restored.first(where: { $0.fileURL.absoluteString == activeStr }) {
                    activeTabID = active.id
                } else {
                    activeTabID = restored.first?.id
                }
                return
            }
        }
        if let first = Self.firstRequestURL(in: workspaceItems) {
            openTab(for: first)
        }
    }

    private static func firstRequestURL(in items: [WorkspaceItem]) -> URL? {
        for item in items {
            switch item {
            case .request(let url):
                return url
            case .folder(_, let children):
                if let url = firstRequestURL(in: children) { return url }
            }
        }
        return nil
    }
}
