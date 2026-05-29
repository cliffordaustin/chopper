import Foundation

/// A folder containing `*.chopper.json` request files.
struct Workspace: Equatable {
    let url: URL

    nonisolated static let `default`: Workspace = {
        let appSupport = (try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let folder = appSupport
            .appendingPathComponent("Chopper", isDirectory: true)
            .appendingPathComponent("Default Workspace", isDirectory: true)
        return Workspace(url: folder)
    }()

    func ensureExists() throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    func listRequestFiles() throws -> [URL] {
        let suffix = "." + RequestFile.fileExtension
        let contents = try FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        return contents
            .filter { $0.lastPathComponent.hasSuffix(suffix) }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }

    /// True if this is the built-in default workspace inside the sandbox container.
    var isDefault: Bool { url == Self.default.url }

    /// Returns the workspace tree (folders and request files) rooted at `url`.
    func scan() -> [WorkspaceItem] {
        Self.scan(directory: url)
    }

    private static func scan(directory: URL) -> [WorkspaceItem] {
        let suffix = "." + RequestFile.fileExtension
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var items: [WorkspaceItem] = []
        for url in contents {
            let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            if isDirectory {
                items.append(.folder(url: url, children: scan(directory: url)))
            } else if url.lastPathComponent.hasSuffix(suffix) {
                let method = (try? RequestStore.read(from: url))?.method
                items.append(.request(url: url, method: method))
            }
        }
        return items.sorted { lhs, rhs in
            // Folders first, then alphabetical.
            switch (lhs, rhs) {
            case (.folder, .request): return true
            case (.request, .folder): return false
            default: return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
        }
    }

    /// Creates an empty request file with a disambiguated name. `parent`
    /// defaults to the workspace root; pass a subfolder URL to nest.
    func createNewRequest(in parent: URL? = nil, baseName: String = "New Request") throws -> URL {
        let parentURL = parent ?? url
        try FileManager.default.createDirectory(at: parentURL, withIntermediateDirectories: true)
        let ext = RequestFile.fileExtension
        let existing = Self.childNames(of: parentURL)

        var candidate = "\(baseName).\(ext)"
        var n = 2
        while existing.contains(candidate) {
            candidate = "\(baseName) \(n).\(ext)"
            n += 1
        }
        let fileURL = parentURL.appendingPathComponent(candidate)
        try RequestStore.write(HTTPRequest(), to: fileURL)
        return fileURL
    }

    /// Creates a subfolder with a disambiguated name.
    func createFolder(in parent: URL? = nil, baseName: String = "New Folder") throws -> URL {
        let parentURL = parent ?? url
        try FileManager.default.createDirectory(at: parentURL, withIntermediateDirectories: true)
        let existing = Self.childNames(of: parentURL)

        var candidate = baseName
        var n = 2
        while existing.contains(candidate) {
            candidate = "\(baseName) \(n)"
            n += 1
        }
        let folderURL = parentURL.appendingPathComponent(candidate, isDirectory: true)
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: false)
        return folderURL
    }

    func rename(_ item: URL, to newBaseName: String) throws -> URL {
        let trimmed = newBaseName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { throw WorkspaceError.invalidName }

        let parent = item.deletingLastPathComponent()
        let suffix = "." + RequestFile.fileExtension
        let isRequest = item.lastPathComponent.hasSuffix(suffix)
        let finalName = isRequest ? "\(trimmed)\(suffix)" : trimmed
        let newURL = parent.appendingPathComponent(finalName)
        if newURL == item { return item }

        if FileManager.default.fileExists(atPath: newURL.path) {
            throw WorkspaceError.nameExists(finalName)
        }
        try FileManager.default.moveItem(at: item, to: newURL)
        return newURL
    }

    /// Removes an item. In a user-chosen (Finder-visible) workspace this moves
    /// to the user's Trash so they can recover it. In the sandbox-container we delete permanently.
    func delete(_ item: URL) throws {
        if isDefault {
            try FileManager.default.removeItem(at: item)
        } else {
            var resulting: NSURL?
            try FileManager.default.trashItem(at: item, resultingItemURL: &resulting)
        }
    }

    private static func childNames(of parent: URL) -> Set<String> {
        let contents = (try? FileManager.default.contentsOfDirectory(atPath: parent.path)) ?? []
        return Set(contents)
    }
}

enum WorkspaceError: LocalizedError {
    case invalidName
    case nameExists(String)

    var errorDescription: String? {
        switch self {
        case .invalidName: return "Name can't be empty."
        case .nameExists(let name): return "\"\(name)\" already exists in this folder."
        }
    }
}
