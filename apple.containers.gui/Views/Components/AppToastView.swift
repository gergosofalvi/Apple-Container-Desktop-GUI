import SwiftUI

struct AppToastView: View {
    let message: String
    let onDismiss: () -> Void
    let onCopy: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.title3)

            Text(message)
                .font(.callout)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)

            HStack(spacing: 8) {
                Button("Copy") {
                    onCopy()
                }
                .buttonStyle(.bordered)

                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.borderless)
                .help("Dismiss")
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.orange.opacity(0.35))
        }
        .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }
}

struct ContainerRunProgressSheet: View {
    @Environment(AppViewModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                if model.isContainerRunInProgress {
                    ProgressView()
                        .controlSize(.regular)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.title2)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(model.containerRunProgressTitle)
                        .font(.headline)
                    Text(model.isContainerRunInProgress ? "Pulling image and starting container…" : "Container started")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            ScrollViewReader { proxy in
                ScrollView {
                    Text(model.containerRunProgressOutput.isEmpty ? "Waiting for output…" : model.containerRunProgressOutput)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(model.containerRunProgressOutput.isEmpty ? Color.secondary : Color.primary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .id("run-output-bottom")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .onChange(of: model.containerRunProgressOutput) { _, _ in
                    proxy.scrollTo("run-output-bottom", anchor: .bottom)
                }
            }
        }
        .padding(20)
        .frame(minWidth: 560, minHeight: 420)
        .interactiveDismissDisabled(model.isContainerRunInProgress)
    }
}
