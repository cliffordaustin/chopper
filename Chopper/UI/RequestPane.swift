import SwiftUI

struct RequestPane: View {
    @Bindable var state: AppState
    @FocusState private var urlFocused: Bool
    @State private var selectedTab: RequestTab = .params

    enum RequestTab: String, CaseIterable, Identifiable {
        case params = "Params"
        case headers = "Headers"
        case body = "Body"
        var id: String { rawValue }

        func badge(for request: HTTPRequest) -> TabBadge? {
            switch self {
            case .params:
                let count = request.queryParams.filter { $0.isEnabled && !$0.name.isEmpty }.count
                return count > 0 ? .count(count) : nil
            case .headers:
                let count = request.headers.filter { $0.isEnabled && !$0.name.isEmpty }.count
                return count > 0 ? .count(count) : nil
            case .body:
                return request.body.isEmpty ? nil : .dot
            }
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Picker("", selection: $state.request.method) {
                    ForEach(HTTPMethod.allCases) { method in
                        Text(method.rawValue).tag(method)
                    }
                }
                .labelsHidden()
                .frame(width: 100)

                TextField("https://api.example.com/endpoint", text: $state.request.url)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .focused($urlFocused)
                    .onSubmit { Task { await state.send() } }

                Button(action: { Task { await state.send() } }) {
                    if state.isLoading {
                        ProgressView()
                            .controlSize(.small)
                            .frame(width: 40)
                    } else {
                        Text("Send")
                            .frame(width: 40)
                    }
                }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(state.isLoading || !state.request.isSendable)
            }

            HStack(spacing: 16) {
                ForEach(RequestTab.allCases) { tab in
                    TabButton(
                        title: tab.rawValue,
                        badge: tab.badge(for: state.request),
                        isSelected: tab == selectedTab
                    ) {
                        selectedTab = tab
                    }
                }
                Spacer()
            }
            .padding(.top, 4)

            Divider()

            switch selectedTab {
            case .params:
                KeyValueEditor(pairs: $state.request.queryParams, namePlaceholder: "Param name", valuePlaceholder: "Value")
            case .headers:
                KeyValueEditor(pairs: $state.request.headers, namePlaceholder: "Header name", valuePlaceholder: "Value")
            case .body:
                BodyEditor(httpBody: $state.request.body)
            }
        }
        .padding(12)
        .onChange(of: state.request.url) { _, _ in state.syncParamsFromURL() }
        .onChange(of: state.request.queryParams) { _, _ in
            // Don't rewrite the URL while the user is mid-typing in it.
            guard !urlFocused else { return }
            state.syncURLFromParams()
        }
    }
}

enum TabBadge: Equatable {
    case count(Int)
    case dot
}

private struct TabButton: View {
    let title: String
    let badge: TabBadge?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                switch badge {
                case .count(let n):
                    Text("\(n)")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.accentColor.opacity(0.2), in: Capsule())
                        .foregroundStyle(Color.accentColor)
                case .dot:
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 6, height: 6)
                case .none:
                    EmptyView()
                }
            }
            .font(.subheadline.weight(isSelected ? .semibold : .regular))
            .foregroundStyle(isSelected ? Color.primary : Color.secondary)
            .padding(.vertical, 4)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(isSelected ? Color.accentColor : Color.clear)
                    .frame(height: 2)
                    .offset(y: 6)
            }
        }
        .buttonStyle(.plain)
    }
}
