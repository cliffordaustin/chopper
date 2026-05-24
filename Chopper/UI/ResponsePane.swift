import SwiftUI

struct ResponsePane: View {
    let state: AppState

    var body: some View {
        Group {
            if let error = state.errorMessage {
                placeholder(systemImage: "exclamationmark.triangle", title: "Request failed", subtitle: error, tint: .red)
            } else if let response = state.response {
                ResponseView(response: response)
            } else if state.isLoading {
                placeholder(systemImage: "arrow.up.arrow.down", title: "Sending…", subtitle: nil, tint: .secondary)
            } else {
                placeholder(systemImage: "tray", title: "No response yet", subtitle: "Send a request to see the response here.", tint: .secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor))
    }

    private func placeholder(systemImage: String, title: String, subtitle: String?, tint: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 28))
                .foregroundStyle(tint)
            Text(title).font(.headline)
            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ResponseView: View {
    let response: HTTPResponse
    @State private var selectedTab: Tab = .body

    enum Tab: String, CaseIterable, Identifiable {
        case body = "Body"
        case headers = "Headers"
        var id: String { rawValue }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 16) {
                StatusBadge(statusCode: response.statusCode)
                Label(formatDuration(response.duration), systemImage: "clock")
                    .foregroundStyle(.secondary)
                Label(formatSize(response.body.count), systemImage: "internaldrive")
                    .foregroundStyle(.secondary)
                Spacer()
                Picker("", selection: $selectedTab) {
                    ForEach(Tab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 180)
            }
            .font(.subheadline)
            .padding(12)

            Divider()

            switch selectedTab {
            case .body:
                ResponseBodyView(response: response)
            case .headers:
                HeadersList(headers: response.headers)
            }
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        if duration < 1 {
            return "\(Int((duration * 1000).rounded())) ms"
        }
        return String(format: "%.2f s", duration)
    }

    private func formatSize(_ bytes: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }
}

private struct StatusBadge: View {
    let statusCode: Int

    var body: some View {
        Text("\(statusCode)")
            .font(.system(.subheadline, design: .monospaced).weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.18), in: RoundedRectangle(cornerRadius: 4))
            .foregroundStyle(color)
    }

    private var color: Color {
        switch statusCode {
        case 200..<300: return .green
        case 300..<400: return .blue
        case 400..<500: return .orange
        case 500..<600: return .red
        default: return .secondary
        }
    }
}

private struct ResponseBodyView: View {
    let response: HTTPResponse
    @State private var displayText: String = ""

    var body: some View {
        ReadOnlyTextView(text: displayText)
            .task(id: response.body) {
                displayText = await Self.formatBody(response.body)
            }
    }

    static func formatBody(_ body: Data) async -> String {
        await Task.detached(priority: .userInitiated) {
            if
                let object = try? JSONSerialization.jsonObject(with: body, options: [.fragmentsAllowed]),
                let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys, .fragmentsAllowed]),
                let pretty = String(data: data, encoding: .utf8)
            {
                return pretty
            }
            if let raw = String(data: body, encoding: .utf8) {
                return raw
            }
            return "<binary data, \(body.count) bytes>"
        }.value
    }
}

private struct ReadOnlyTextView: NSViewRepresentable {
    let text: String

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = false
        scrollView.borderType = .noBorder

        let textView = scrollView.documentView as! NSTextView
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = false
        textView.drawsBackground = true
        textView.backgroundColor = .textBackgroundColor
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.font = .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        textView.isHorizontallyResizable = true
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        if textView.string != text {
            textView.string = text
        }
    }
}

private struct HeadersList: View {
    let headers: [String: String]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(headers.keys.sorted(), id: \.self) { key in
                    HStack(alignment: .top, spacing: 12) {
                        Text(key)
                            .font(.system(.body, design: .monospaced).weight(.medium))
                            .frame(width: 200, alignment: .leading)
                        Text(headers[key] ?? "")
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    Divider()
                }
            }
        }
    }
}
