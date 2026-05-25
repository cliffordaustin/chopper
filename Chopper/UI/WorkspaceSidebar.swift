import AppKit
import SwiftUI

struct WorkspaceSidebar: View {
    let state: AppState

    @State private var renameTarget: URL?
    @State private var renameText: String = ""

    @State private var deleteTarget: URL?
    @State private var deleteIsFolder: Bool = false

    var body: some View {
        List(selection: Binding<URL?>(
            get: { state.activeTab?.fileURL },
            set: { newValue in
                guard let url = newValue, url != state.activeTab?.fileURL else { return }
                guard url.lastPathComponent.hasSuffix("." + RequestFile.fileExtension) else { return }
                state.openTab(for: url)
            }
        )) {
            OutlineGroup(state.workspaceItems, children: \.children) { item in
                row(for: item)
                    .tag(item.url)
                    .contextMenu { contextMenu(for: item) }
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 200)
        .navigationTitle(state.workspace.url.lastPathComponent)
        .toolbar { toolbarContent }
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

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem {
            Menu {
                Button("New Request") { state.newRequest() }
                Button("New Folder") { state.createFolder() }
            } label: {
                Label("Add", systemImage: "plus")
            }
            .menuStyle(.borderlessButton)
        }
    }

    // MARK: - Row

    @ViewBuilder
    private func row(for item: WorkspaceItem) -> some View {
        switch item {
        case .folder:
            Label(item.name, systemImage: "folder")
        case .request(let url):
            Label(item.name, systemImage: "doc.text")
                .foregroundStyle(url == state.activeTab?.fileURL ? Color.accentColor : Color.primary)
        }
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
