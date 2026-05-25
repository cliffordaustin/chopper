import SwiftUI

struct ContentView: View {
    let state: AppState

    var body: some View {
        NavigationSplitView {
            WorkspaceSidebar(state: state)
        } detail: {
            VStack(spacing: 0) {
                TabBar(state: state)
                Divider()
                if let tab = state.activeTab {
                    VSplitView {
                        RequestPane(tab: tab)
                            .frame(minHeight: 120)
                        ResponsePane(tab: tab)
                            .frame(minHeight: 200)
                    }
                    .onChange(of: tab.request) { _, _ in tab.scheduleAutosave() }
                } else {
                    EmptyTabPlaceholder(state: state)
                }
            }
            .frame(minWidth: 560, minHeight: 480)
            .navigationTitle(state.activeTab?.displayName ?? "Chopper")
            .background(
                // Hidden focused button beats the system Close Window shortcut.
                Button("") { state.closeActiveTab() }
                    .keyboardShortcut("w", modifiers: [.command])
                    .opacity(0)
                    .allowsHitTesting(false)
            )
        }
    }
}

private struct EmptyTabPlaceholder: View {
    let state: AppState

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "tray")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
            Text("No tabs open")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Create a new request or pick one from the sidebar.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
            Button {
                state.newRequest()
            } label: {
                Label("New Request", systemImage: "plus")
                    .padding(.horizontal, 6)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .keyboardShortcut("n", modifiers: [.command])
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

#Preview {
    ContentView(state: AppState())
}
