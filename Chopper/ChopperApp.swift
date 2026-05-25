import AppKit
import SwiftUI
import UniformTypeIdentifiers

@main
struct ChopperApp: App {
    @State private var state = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView(state: state)
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 960, height: 640)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Request") { state.newRequest() }
                    .keyboardShortcut("n", modifiers: [.command])
                Button("Open Request…") { runOpenRequestPanel() }
                    .keyboardShortcut("o", modifiers: [.command])
                Divider()
                Button("Open Workspace…") { runOpenWorkspacePanel() }
                    .keyboardShortcut("o", modifiers: [.command, .shift])
                Button("Use Default Workspace") {
                    do { try state.switchWorkspace(to: nil) }
                    catch { NSAlert(error: error).runModal() }
                }
                .disabled(state.workspace.isDefault)
            }
            CommandGroup(after: .windowArrangement) {
                // Shortcut handled by hidden button in ContentView so it wins
                // over SwiftUI's built-in Close Window ⌘W.
                Button("Close Tab") { state.closeActiveTab() }
                    .disabled(state.activeTab == nil)
            }
        }
    }

    private func runOpenRequestPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            state.openTab(for: url)
        }
    }

    private func runOpenWorkspacePanel() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Choose Workspace"
        if panel.runModal() == .OK, let url = panel.url {
            do { try state.switchWorkspace(to: url) }
            catch { NSAlert(error: error).runModal() }
        }
    }
}
