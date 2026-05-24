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
    @State private var mode: BodyMode = .pretty
    @State private var attributedText = NSAttributedString()
    @Environment(\.colorScheme) private var colorScheme

    enum BodyMode: String, CaseIterable, Identifiable {
        case pretty = "Pretty"
        case raw = "Raw"
        var id: String { rawValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Picker("", selection: $mode) {
                    ForEach(BodyMode.allCases) { Text($0.rawValue).tag($0) }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 130)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            AttributedTextView(text: attributedText)
        }
        .task(id: TaskKey(body: response.body, mode: mode, scheme: colorScheme)) {
            let body = response.body
            let mode = mode
            let scheme = colorScheme
            let isJSON = isJSON
            let rendered = await Task.detached(priority: .userInitiated) {
                Self.buildAttributed(body: body, mode: mode, scheme: scheme, isJSON: isJSON)
            }.value
            if !Task.isCancelled {
                attributedText = rendered
            }
        }
    }

    private struct TaskKey: Hashable {
        let body: Data
        let mode: BodyMode
        let scheme: ColorScheme
    }

    private var isJSON: Bool {
        guard
            let contentType = response.headers.first(where: { $0.key.lowercased() == "content-type" })?.value.lowercased()
        else { return false }
        return contentType.contains("json")
    }

    private static func buildAttributed(body: Data, mode: BodyMode, scheme: ColorScheme, isJSON: Bool) -> NSAttributedString {
        let raw = String(data: body, encoding: .utf8)
            ?? "<binary data, \(body.count) bytes>"

        let display: String
        switch mode {
        case .pretty where isJSON:
            display = prettyJSON(body) ?? raw
        case .pretty:
            display = raw
        case .raw:
            display = softWrap(raw, every: 200)
        }

        if mode == .pretty && isJSON {
            return JSONHighlighter.highlight(display, scheme: scheme)
        } else {
            return plainText(display, scheme: scheme)
        }
    }

    // TextKit wraps per-paragraph, so a multi-MB no-newline body blocks the main
    // thread. Inject display-only newlines to split it into short paragraphs
    private static func softWrap(_ source: String, every maxLineChars: Int) -> String {
        guard source.count > maxLineChars else { return source }
        var out = String()
        out.reserveCapacity(source.utf8.count + source.utf8.count / maxLineChars)
        var lineLen = 0
        for ch in source {
            out.append(ch)
            if ch == "\n" {
                lineLen = 0
                continue
            }
            lineLen += 1
            // Break after a structural char once the line is long enough,
            // or hard-break if we run far past the limit.
            if lineLen >= maxLineChars && (ch == "," || ch == "}" || ch == "]" || ch == " ") {
                out.append("\n")
                lineLen = 0
            } else if lineLen >= maxLineChars * 2 {
                out.append("\n")
                lineLen = 0
            }
        }
        return out
    }

    static func prettyJSON(_ data: Data) -> String? {
        guard
            let object = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]),
            let pretty = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys, .fragmentsAllowed]),
            let string = String(data: pretty, encoding: .utf8)
        else { return nil }
        return string
    }

    static func plainText(_ text: String, scheme: ColorScheme) -> NSAttributedString {
        let font = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        let color: NSColor = scheme == .dark ? NSColor(white: 0.88, alpha: 1.0) : NSColor(white: 0.12, alpha: 1.0)
        return NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: color])
    }
}

private struct AttributedTextView: NSViewRepresentable {
    let text: NSAttributedString

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        let textView = scrollView.documentView as! NSTextView
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = true
        textView.drawsBackground = true
        textView.backgroundColor = .textBackgroundColor
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        textView.layoutManager?.allowsNonContiguousLayout = true
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        textView.textStorage?.setAttributedString(text)
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
