import SwiftUI

struct TabBar: View {
    @Bindable var state: AppState

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(state.tabs) { tab in
                    TabBarItem(
                        tab: tab,
                        isActive: tab.id == state.activeTabID,
                        method: tab.request.method,
                        onActivate: { state.setActiveTab(tab.id) },
                        onClose: { state.closeTab(tab.id) }
                    )
                    Divider().frame(height: 18)
                }
            }
        }
        .frame(height: 32)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

private struct TabBarItem: View {
    let tab: Tab
    let isActive: Bool
    let method: HTTPMethod
    let onActivate: () -> Void
    let onClose: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 6) {
            Text(method.rawValue)
                .font(.system(.caption2, design: .monospaced).weight(.semibold))
                .foregroundStyle(methodColor)
            Text(tab.displayName)
                .font(.subheadline)
                .lineLimit(1)
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .frame(width: 14, height: 14)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .opacity(isHovering || isActive ? 0.7 : 0.0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(isActive ? Color(nsColor: .controlBackgroundColor) : Color.clear)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(isActive ? Color.accentColor : Color.clear)
                .frame(height: 2)
        }
        .contentShape(Rectangle())
        .onTapGesture { onActivate() }
        .onHover { isHovering = $0 }
    }

    private var methodColor: Color {
        switch method {
        case .get: return .green
        case .post: return .orange
        case .put, .patch: return .blue
        case .delete: return .red
        }
    }
}
