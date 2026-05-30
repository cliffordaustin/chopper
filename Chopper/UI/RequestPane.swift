import SwiftUI

struct RequestPane: View {
    @Bindable var tab: Tab
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
                Picker("", selection: $tab.request.method) {
                    ForEach(HTTPMethod.allCases) { method in
                        Text(method.rawValue).tag(method)
                    }
                }
                .labelsHidden()
                .frame(width: 100)

                TextField("https://api.example.com/endpoint", text: $tab.request.url)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                    .focused($urlFocused)
                    .onSubmit { Task { await tab.send() } }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Theme.Colors.cardBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(
                                urlFocused ? Color.accentColor : Theme.Colors.separator,
                                lineWidth: urlFocused ? 2 : 1
                            )
                    )

                Button(action: { Task { await tab.send() } }) {
                    if tab.isLoading {
                        ProgressView()
                            .controlSize(.small)
                            .frame(width: 40)
                    } else {
                        Text("Send")
                            .frame(width: 40)
                    }
                }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(tab.isLoading || !tab.request.isSendable)
            }

            HStack(spacing: 16) {
                ForEach(RequestTab.allCases) { rt in
                    TabButton(
                        title: rt.rawValue,
                        badge: rt.badge(for: tab.request),
                        isSelected: rt == selectedTab
                    ) {
                        selectedTab = rt
                    }
                }
                Spacer()
            }
            .padding(.top, 4)

            Divider()

            switch selectedTab {
            case .params:
                KeyValueEditor(pairs: $tab.request.queryParams, namePlaceholder: "Param name", valuePlaceholder: "Value")
            case .headers:
                KeyValueEditor(pairs: $tab.request.headers, namePlaceholder: "Header name", valuePlaceholder: "Value")
            case .body:
                BodyEditor(httpBody: $tab.request.body)
            }
        }
        .padding(12)
        .onChange(of: tab.request.url) { _, _ in tab.syncParamsFromURL() }
        .onChange(of: tab.request.queryParams) { _, _ in
            guard !urlFocused else { return }
            tab.syncURLFromParams()
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
