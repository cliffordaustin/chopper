import AppKit
import SwiftUI

struct ContentView: View {
    let state: AppState

    @AppStorage("Chopper.sidebarWidth") private var sidebarWidth: Double = 260
    @AppStorage("Chopper.sidebarCollapsed") private var sidebarCollapsed = false
    @State private var isFullscreen = false
    @State private var hoverRevealed = false

    /// Window-edge insets so the sidebar and content read as inset cards.
    private let edgePadding: CGFloat = 8
    /// Inset-card corner radius. macOS 26 (Tahoe) enlarged the window corner radius
    private var cardCornerRadius: CGFloat {
        if #available(macOS 26, *) { 20 } else { 10 }
    }
    /// Vertical space above content so it clears the traffic-light buttons.
    /// The sidebar handles this internally so its background extends behind the toolbar area instead of leaving a bare gutter above the card.
    /// Matches the `.unified` NSToolbar height we install below. Drops to 0 in fullscreen since there are no traffic lights to clear.
    private var topGutter: CGFloat { isFullscreen ? 15 : 38 }

    private var sidebarAnimation: Animation { .spring(response: 0.34, dampingFraction: 0.86) }

    var body: some View {
        ZStack(alignment: .topLeading) {
            HStack(spacing: 0) {
                if !sidebarCollapsed {
                    sidebarCard(floating: false)
                        .transition(.move(edge: .leading))

                    SidebarResizer(width: $sidebarWidth, min: 220, max: 420)
                        .padding(.top, topGutter)
                        .padding(.bottom, edgePadding)
                        .transition(.opacity)
                }

                VStack(spacing: 0) {
                    TabBar(state: state)
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
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, topGutter)
                .padding(.trailing, edgePadding)
                .padding(.bottom, edgePadding)
            }

            if sidebarCollapsed {
                // Thin left-edge strip that reveals the floating sidebar.
                Color.clear
                    .frame(width: 8)
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .onHover { hovering in
                        if hovering {
                            withAnimation(sidebarAnimation) { hoverRevealed = true }
                        }
                    }

                if hoverRevealed {
                    sidebarCard(floating: true)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                        .onHover { hovering in
                            if !hovering {
                                withAnimation(sidebarAnimation) { hoverRevealed = false }
                            }
                        }
                        .zIndex(1)
                }
            }
        }
        .frame(minWidth: 600, minHeight: 380)
        .background(Theme.Colors.windowBackground)
        .ignoresSafeArea()
        .background(
            // Hidden focused button beats the system Close Window shortcut.
            Button("") { state.closeActiveTab() }
                .keyboardShortcut("w", modifiers: [.command])
                .opacity(0)
                .allowsHitTesting(false)
        )
        .background(
            WindowAccessor { window in
                configure(window: window)
            }
        )
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didEnterFullScreenNotification)) { _ in
            handleFullscreenChange(true)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didExitFullScreenNotification)) { _ in
            handleFullscreenChange(false)
        }
    }

    /// The sidebar plus its rounded card chrome. In `floating` mode it sits
    /// below the traffic-light bar with a drop shadow so it reads as an overlay
    /// that floats over the content rather than occupying layout.
    @ViewBuilder
    private func sidebarCard(floating: Bool) -> some View {
        WorkspaceSidebar(
            state: state,
            topInset: topGutter,
            onToggleCollapse: {
                withAnimation(sidebarAnimation) {
                    sidebarCollapsed.toggle()
                    hoverRevealed = false
                }
            }
        )
        .frame(width: CGFloat(sidebarWidth))
        .background(
            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .fill(Theme.Colors.sidebarBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .strokeBorder(Theme.Colors.sidebarBorder, lineWidth: 1)
        )
        .shadow(color: floating ? Color.black.opacity(0.25) : .clear,
                radius: floating ? 12 : 0, y: floating ? 2 : 0)
        .padding(.top, edgePadding)
        .padding(.bottom, edgePadding)
        .padding(.leading, edgePadding)
    }

    private func configure(window: NSWindow) {
        let visible = (window.screen ?? NSScreen.main)?.visibleFrame ?? window.frame

        let key = "Chopper.didSetInitialWindowFrame"
        let isFirstLaunch = !UserDefaults.standard.bool(forKey: key)

        let current = window.frame
        let isOutside = current.minX < visible.minX
            || current.minY < visible.minY
            || current.maxX > visible.maxX
            || current.maxY > visible.maxY

        if isFirstLaunch || isOutside {
            window.setFrame(visible, display: true)
            UserDefaults.standard.set(true, forKey: key)
        }

        installTitlebarToolbar(on: window)
    }

    /// Gives the window a stable, taller titlebar area so the traffic-light
    /// buttons sit naturally inside it.
    private func installTitlebarToolbar(on window: NSWindow) {
        window.styleMask.insert(.fullSizeContentView)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden

        if window.toolbar == nil {
            let toolbar = NSToolbar(identifier: "Chopper.MainToolbar")
            if #available(macOS 15, *) {
                // Do nothing; separator behavior follows toolbarStyle.
            } else {
                toolbar.showsBaselineSeparator = false
            }
            window.toolbar = toolbar
            window.toolbarStyle = .unified
        }

        isFullscreen = window.styleMask.contains(.fullScreen)
        window.toolbar?.isVisible = !isFullscreen
    }

    /// Hides the toolbar in fullscreen-there are no traffic lights to host
    /// there, and otherwise the empty bar eats ~38pt of content space.
    private func handleFullscreenChange(_ entering: Bool) {
        isFullscreen = entering
        if let window = NSApp.keyWindow ?? NSApp.windows.first {
            window.toolbar?.isVisible = !entering
        }
    }
}


private struct WindowAccessor: NSViewRepresentable {
    let onWindow: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                onWindow(window)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard nsView.window == nil else { return }
        DispatchQueue.main.async {
            if let window = nsView.window {
                onWindow(window)
            }
        }
    }
}

private struct SidebarResizer: View {
    @Binding var width: Double
    let min: Double
    let max: Double

    @State private var startWidth: Double? = nil

    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(width: 8)
            .contentShape(Rectangle())
            .overlay(ResizeCursorView())
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .global)
                    .onChanged { value in
                        let base = startWidth ?? width
                        if startWidth == nil { startWidth = width }
                        let next = base + Double(value.translation.width)
                        width = Swift.min(Swift.max(next, min), max)
                    }
                    .onEnded { _ in startWidth = nil }
            )
    }
}

/// Manages the resize cursor via AppKit's cursor-rect system
private struct ResizeCursorView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { CursorView() }
    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class CursorView: NSView {
        override func resetCursorRects() {
            addCursorRect(bounds, cursor: .resizeLeftRight)
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
    }
}

#Preview {
    ContentView(state: AppState())
}
