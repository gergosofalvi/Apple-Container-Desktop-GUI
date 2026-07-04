import SwiftUI

struct SettingsListPanel: View {
    var body: some View {
        ContentUnavailableView {
            Label("Settings", systemImage: "gearshape")
        } description: {
            Text("Configure the app in the detail panel.")
        }
    }
}

struct SettingsView: View {
    @Environment(AppViewModel.self) private var model

    var body: some View {
        @Bindable var model = model

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                DetailHeaderView(
                    title: "Settings",
                    subtitle: "Application preferences",
                    status: "ready",
                    isRunning: true
                )

                GroupBox("Data Directory") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Default base folder for template volume mounts. Example: WordPress uses BASE/wordpress.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        HStack(spacing: 8) {
                            TextField("~/Documents/containers-data.nosync", text: $model.defaultDataDirectory)
                                .textFieldStyle(.roundedBorder)

                            PathBrowseButton(
                                path: $model.defaultDataDirectory,
                                allowsDirectories: true,
                                allowsFiles: false,
                                title: "Choose…"
                            )
                        }

                        Text("Current path: \(VolumeMountPaths.expandedDefaultDataDirectory)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox("Terminal") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Exec tabs use an integrated terminal inside the app (SwiftTerm). External Terminal/iTerm2 is only used when you explicitly choose Open in Terminal.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Picker("Default terminal", selection: $model.preferredTerminal) {
                            ForEach(model.availableTerminals) { terminal in
                                Text(terminal.displayName).tag(terminal)
                            }
                        }
                        .pickerStyle(.radioGroup)
                        .labelsHidden()

                        if !TerminalApplication.isInstalled(.iterm2) {
                            Label(
                                "Install iTerm2 to enable it here.",
                                systemImage: "info.circle"
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox("About") {
                    KeyValueGrid(rows: [
                        ("CLI version", model.cliVersion.isEmpty ? "—" : model.cliVersion),
                        ("CLI installed", model.isCLIInstalled ? "Yes" : "No"),
                    ])
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .navigationTitle("Settings")
    }
}
