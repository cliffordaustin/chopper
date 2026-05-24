import SwiftUI

struct KeyValueEditor: View {
    @Binding var pairs: [KeyValuePair]
    let namePlaceholder: String
    let valuePlaceholder: String

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Text("")
                        .frame(width: 18)
                    Text("Name")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Value")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("")
                        .frame(width: 22)
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
                .padding(.bottom, 4)

                ForEach($pairs) { $pair in
                    KeyValueRow(
                        pair: $pair,
                        namePlaceholder: namePlaceholder,
                        valuePlaceholder: valuePlaceholder,
                        isTrailing: pair.id == pairs.last?.id
                    ) {
                        pairs.removeAll { $0.id == pair.id }
                        ensureTrailingBlank()
                    }
                    Divider()
                }
            }
        }
        .onAppear { ensureTrailingBlank() }
        .onChange(of: pairs) { _, _ in ensureTrailingBlank() }
    }

    private func ensureTrailingBlank() {
        if pairs.last?.isBlank != true {
            pairs.append(KeyValuePair())
        }
    }
}

private struct KeyValueRow: View {
    @Binding var pair: KeyValuePair
    let namePlaceholder: String
    let valuePlaceholder: String
    let isTrailing: Bool
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            if isTrailing {
                Color.clear.frame(width: 18, height: 18)
            } else {
                Toggle("", isOn: $pair.isEnabled)
                    .toggleStyle(.checkbox)
                    .labelsHidden()
                    .frame(width: 18)
            }

            TextField(namePlaceholder, text: $pair.name)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .font(.system(.body, design: .monospaced))

            TextField(valuePlaceholder, text: $pair.value)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .font(.system(.body, design: .monospaced))

            if isTrailing {
                Color.clear.frame(width: 22, height: 22)
            } else {
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .frame(width: 22)
                .help("Remove row")
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .opacity(!isTrailing && !pair.isEnabled ? 0.5 : 1.0)
    }
}
