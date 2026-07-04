import SwiftUI

struct FormErrorBanner: View {
    let message: String
    var terminalCommand: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let terminalCommand {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Terminal command")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(terminalCommand)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(nsColor: .textBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 6))

                    Button("Open Terminal") {
                        try? TerminalLauncher.openPrefilledCommand(terminalCommand)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(12)
        .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
    }
}

struct FormTextField: View {
    let title: String
    let help: String
    let placeholder: String
    @Binding var text: String
    var isRequired = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.headline)
                if isRequired {
                    Text("*")
                        .foregroundStyle(.red)
                }
            }

            Text(help)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            TextField(placeholder, text: $text)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct FormTextEditor: View {
    let title: String
    let help: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)

            Text(help)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(.body)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 8)
                        .allowsHitTesting(false)
                }

                TextEditor(text: $text)
                    .font(.body)
                    .frame(minHeight: 72)
                    .scrollContentBackground(.hidden)
                    .padding(4)
            }
            .background(Color(nsColor: .textBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct FormSectionHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title3.weight(.semibold))
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct LeftAlignedGroupBox<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    init(_ title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        GroupBox(title) {
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
