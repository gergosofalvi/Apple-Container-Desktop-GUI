import SwiftUI

struct ContainerWorkspacePanel: View {
    @Environment(AppViewModel.self) private var model

    var body: some View {
        @Bindable var model = model

        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(model.workspaceTabs) { tab in
                            WorkspaceTabButton(
                                tab: tab,
                                isSelected: model.selectedWorkspaceTabID == tab.id,
                                onSelect: { model.selectWorkspaceTab(tab.id) },
                                onClose: { model.closeWorkspaceTab(tab.id) }
                            )
                        }

                        if let containerID = model.selectedContainerID {
                            Menu {
                                Button {
                                    model.openWorkspaceLogs(for: containerID)
                                } label: {
                                    Label("New Logs tab", systemImage: "doc.text.fill")
                                }
                                Button {
                                    model.openWorkspaceExec(for: containerID)
                                } label: {
                                    Label("New Exec tab", systemImage: "terminal.fill")
                                }
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                            }
                            .menuStyle(.borderlessButton)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                }

                Spacer()

                Button {
                    model.closeWorkspacePanel()
                } label: {
                    Image(systemName: "chevron.down.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .help("Hide panel")
                .padding(.trailing, 8)
            }
            .background(Color(nsColor: .windowBackgroundColor).opacity(0.95))

            Divider()

            ZStack {
                ForEach(model.workspaceTabs) { tab in
                    Group {
                        switch tab.kind {
                        case .logs:
                            WorkspaceLogsContent(containerID: tab.containerID)
                        case .exec:
                            IntegratedContainerTerminalView(
                                containerID: tab.containerID,
                                binaryPath: model.containerCLIPath
                            )
                        }
                    }
                    .opacity(model.selectedWorkspaceTabID == tab.id ? 1 : 0)
                    .allowsHitTesting(model.selectedWorkspaceTabID == tab.id)
                }

                if model.workspaceTabs.isEmpty {
                    ContentUnavailableView("No tabs open", systemImage: "square.dashed")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial)
    }
}

private struct WorkspaceTabButton: View {
    let tab: WorkspaceTab
    let isSelected: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    private var icon: String {
        tab.kind == .logs ? "doc.text.fill" : "terminal.fill"
    }

    private var tint: Color {
        tab.kind == .logs ? .blue : .purple
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(tint)

            Button(action: onSelect) {
                Text(tab.title)
                    .font(.caption.weight(isSelected ? .semibold : .regular))
                    .lineLimit(1)
            }
            .buttonStyle(.plain)

            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(isSelected ? tint.opacity(0.15) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct WorkspaceLogsContent: View {
    @Environment(AppViewModel.self) private var model
    let containerID: String

    @State private var logs = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var autoRefresh = true

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label(containerID, systemImage: "doc.text.fill")
                    .font(.caption)
                    .foregroundStyle(.blue)
                    .lineLimit(1)
                Spacer()
                Toggle("Auto-refresh", isOn: $autoRefresh)
                    .toggleStyle(.checkbox)
                    .font(.caption)
                Button("Refresh") {
                    Task { await loadLogs() }
                }
                .disabled(isLoading)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            Group {
                if isLoading && logs.isEmpty {
                    ProgressView("Loading logs…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage {
                    ContentUnavailableView(
                        "Unable to load logs",
                        systemImage: "exclamationmark.triangle",
                        description: Text(errorMessage)
                    )
                } else if logs.isEmpty {
                    ContentUnavailableView(
                        "No logs captured",
                        systemImage: "doc.text",
                        description: Text("Many images produce no stdout/stderr until they serve traffic. Open Exec to run commands inside the container.")
                    )
                } else {
                    ScrollView {
                        ScrollViewReader { proxy in
                            Text(logs)
                                .font(.system(.body, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .id("logs-end")
                                .onChange(of: logs) { _, _ in
                                    proxy.scrollTo("logs-end", anchor: .bottom)
                                }
                        }
                    }
                    .background(Color(nsColor: .textBackgroundColor))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .task(id: containerID) {
            await loadLogs()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                guard autoRefresh else { continue }
                await loadLogs(silent: true)
            }
        }
    }

    private func loadLogs(silent: Bool = false) async {
        if !silent { isLoading = true }
        defer { if !silent { isLoading = false } }

        do {
            logs = try await model.fetchLogs(for: containerID)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
