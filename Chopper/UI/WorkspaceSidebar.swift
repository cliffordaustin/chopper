import AppKit
import SwiftUI

struct WorkspaceSidebar: View {
    let state: AppState
    /// Space reserved above the header so the traffic-light buttons can sit
    /// over the sidebar background without overlapping the workspace title.
    var topInset: CGFloat = 0

    @State private var renameTarget: URL?
    @State private var renameText: String = ""

    @State private var deleteTarget: URL?
    @State private var deleteIsFolder: Bool = false

    @State private var hoveredURL: URL?
    @State private var expandedFolders: Set<URL> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear.frame(height: topInset)
            header
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 1) {
                    ForEach(state.workspaceItems) { item in
                        ItemView(
                            item: item,
                            depth: 0,
                            activeURL: state.activeTab?.fileURL,
                            hoveredURL: $hoveredURL,
                            expandedFolders: $expandedFolders,
                            onOpen: { url in state.openTab(for: url) },
                            contextMenu: { contextMenu(for: $0) }
                        )
                    }
                }
                .padding(.horizontal, 8)
                .padding(.top, 4)
                .padding(.bottom, 8)
            }
        }
        .frame(minWidth: 220)
        .alert("Rename", isPresented: Binding(
            get: { renameTarget != nil },
            set: { if !$0 { renameTarget = nil } }
        ), presenting: renameTarget) { url in
            TextField("Name", text: $renameText)
            Button("Rename") { performRename(at: url) }
            Button("Cancel", role: .cancel) {}
        }
        .alert(deletePromptTitle, isPresented: Binding(
            get: { deleteTarget != nil },
            set: { if !$0 { deleteTarget = nil } }
        ), presenting: deleteTarget) { url in
            Button(deleteButtonLabel, role: .destructive) { performDelete(at: url) }
            Button("Cancel", role: .cancel) {}
        } message: { url in
            Text(deleteMessage(for: url))
        }
    }

    // MARK: - Header / footer

    private var header: some View {
        HStack(spacing: Theme.Spacing.s) {
            Image(systemName: "shippingbox")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Text(state.workspace.url.lastPathComponent)
                .font(.system(size: Theme.FontSize.body, weight: .semibold))
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            Menu {
                Button("New Request") { state.newRequest() }
                Button("New Folder") { state.createFolder() }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 22, height: 22)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: - Delete copy

    private var goesToTrash: Bool { !state.workspace.isDefault }
    private var deletePromptTitle: String { goesToTrash ? "Move to Trash?" : "Delete?" }
    private var deleteButtonLabel: String { goesToTrash ? "Move to Trash" : "Delete" }

    private func deleteMessage(for url: URL) -> String {
        let name = displayName(for: url)
        let action = goesToTrash ? "moved to the Trash" : "permanently deleted"
        if deleteIsFolder {
            return "\"\(name)\" and everything inside it will be \(action)."
        }
        return "\"\(name)\" will be \(action)."
    }

    // MARK: - Context menu

    @ViewBuilder
    private func contextMenu(for item: WorkspaceItem) -> some View {
        if case .folder(let url, _) = item {
            Button("New Request") { state.newRequest(in: url) }
            Button("New Folder") { state.createFolder(in: url) }
            Divider()
        }
        Button("Rename…") { beginRename(item.url) }
        Button(goesToTrash ? "Move to Trash" : "Delete") { beginDelete(item) }
    }

    // MARK: - Rename / delete actions

    private func beginRename(_ url: URL) {
        renameText = displayName(for: url)
        renameTarget = url
    }

    private func performRename(at url: URL) {
        do { try state.renameItem(at: url, to: renameText) }
        catch { NSAlert(error: error).runModal() }
    }

    private func beginDelete(_ item: WorkspaceItem) {
        deleteIsFolder = item.children != nil
        deleteTarget = item.url
    }

    private func performDelete(at url: URL) {
        do { try state.deleteItem(at: url) }
        catch { NSAlert(error: error).runModal() }
    }

    private func displayName(for url: URL) -> String {
        let suffix = "." + RequestFile.fileExtension
        let name = url.lastPathComponent
        if name.hasSuffix(suffix) {
            return String(name.dropLast(suffix.count))
        }
        return name
    }
}

// MARK: - Item view

private struct ItemView: View {
    let item: WorkspaceItem
    let depth: Int
    let activeURL: URL?
    @Binding var hoveredURL: URL?
    @Binding var expandedFolders: Set<URL>
    let onOpen: (URL) -> Void
    let contextMenu: (WorkspaceItem) -> AnyView

    init(
        item: WorkspaceItem,
        depth: Int,
        activeURL: URL?,
        hoveredURL: Binding<URL?>,
        expandedFolders: Binding<Set<URL>>,
        onOpen: @escaping (URL) -> Void,
        @ViewBuilder contextMenu: @escaping (WorkspaceItem) -> some View
    ) {
        self.item = item
        self.depth = depth
        self.activeURL = activeURL
        self._hoveredURL = hoveredURL
        self._expandedFolders = expandedFolders
        self.onOpen = onOpen
        self.contextMenu = { item in AnyView(contextMenu(item)) }
    }

    var body: some View {
        switch item {
        case .folder(let url, let children):
            let isExpanded = expandedFolders.contains(url)
            VStack(alignment: .leading, spacing: 1) {
                folderRow(url: url, isExpanded: isExpanded)
                if isExpanded {
                    ForEach(children) { child in
                        ItemView(
                            item: child,
                            depth: depth + 1,
                            activeURL: activeURL,
                            hoveredURL: $hoveredURL,
                            expandedFolders: $expandedFolders,
                            onOpen: onOpen,
                            contextMenu: { AnyView(contextMenu($0)) }
                        )
                    }
                }
            }
        case .request(let url, let method):
            requestRow(url: url, name: item.name, method: method)
        }
    }

    private func folderRow(url: URL, isExpanded: Bool) -> some View {
        let isHover = hoveredURL == url
        return HStack(spacing: 6) {
            Image(systemName: "chevron.right")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 12)
                .rotationEffect(.degrees(isExpanded ? 90 : 0))
            Image(systemName: isExpanded ? "folder.fill" : "folder")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 16)
            Text(item.name)
                .font(.system(size: Theme.FontSize.body))
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.leading, indent)
        .padding(.trailing, 8)
        .padding(.vertical, 5)
        .background(rowBackground(isActive: false, isHover: isHover))
        .contentShape(Rectangle())
        .onTapGesture {
            if isExpanded { expandedFolders.remove(url) } else { expandedFolders.insert(url) }
        }
        .onHover { hovering in
            if hovering { hoveredURL = url } else if hoveredURL == url { hoveredURL = nil }
        }
        .contextMenu { contextMenu(item) }
    }

    private func requestRow(url: URL, name: String, method: HTTPMethod?) -> some View {
        let isActive = url == activeURL
        let isHover = hoveredURL == url
        return HStack(spacing: 6) {
            Spacer().frame(width: 12) // align with folder chevron column
            if let method {
                MethodBadge(method: method, compact: true)
            } else {
                Image(systemName: "doc.text")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, alignment: .leading)
            }
            Text(name)
                .font(.system(size: Theme.FontSize.body, weight: isActive ? .medium : .regular))
                .lineLimit(1)
                .foregroundStyle(isActive ? Color.primary : Color.primary.opacity(0.88))
            Spacer(minLength: 0)
        }
        .padding(.leading, indent)
        .padding(.trailing, 8)
        .padding(.vertical, 5)
        .background(rowBackground(isActive: isActive, isHover: isHover))
        .contentShape(Rectangle())
        .onTapGesture { onOpen(url) }
        .onHover { hovering in
            if hovering { hoveredURL = url } else if hoveredURL == url { hoveredURL = nil }
        }
        .contextMenu { contextMenu(item) }
    }

    private var indent: CGFloat { 6 + CGFloat(depth) * 14 }

    @ViewBuilder
    private func rowBackground(isActive: Bool, isHover: Bool) -> some View {
        let fill: Color = {
            if isActive { return Theme.Colors.subtleSelection }
            if isHover { return Theme.Colors.subtleHover }
            return .clear
        }()
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(fill)
    }
}
