import SwiftUI
import AppKit

struct ImagePresetPicker: View {
    @Binding var form: CreateContainerForm
    @State private var selectedCategory = ImagePresets.categories.first ?? "Base"
    @State private var searchText = ""

    private var filteredPresets: [ImagePreset] {
        let categoryPresets = ImagePresets.presets(in: selectedCategory)
        guard !searchText.isEmpty else { return categoryPresets }
        let query = searchText.lowercased()
        return categoryPresets.filter {
            $0.name.lowercased().contains(query) ||
            $0.image.lowercased().contains(query) ||
            $0.description.lowercased().contains(query)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick start templates")
                .font(.headline)

            Text("Pick a popular image to pre-fill ports, volumes, and environment.")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField("Search images…", text: $searchText)
                .textFieldStyle(.roundedBorder)

            Picker("Category", selection: $selectedCategory) {
                ForEach(ImagePresets.categories, id: \.self) { category in
                    Text(category).tag(category)
                }
            }
            .pickerStyle(.menu)

            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 8)], spacing: 8) {
                    ForEach(filteredPresets) { preset in
                        Button {
                            form.applyPreset(preset)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(preset.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Text(preset.image)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                Text(preset.description)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(2)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay {
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(Color.secondary.opacity(0.15))
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxHeight: 220)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct PortMappingsEditor: View {
    @Binding var portMappings: [PortMapping]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Port mappings")
                    .font(.headline)
                Spacer()
                Button {
                    portMappings.append(PortMapping())
                } label: {
                    Label("Add port", systemImage: "plus")
                }
            }

            Text("Map a host port to a container port.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if portMappings.isEmpty {
                Text("No ports published.")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 8)
            } else {
                ForEach($portMappings) { $mapping in
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Host")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            TextField("8080", text: $mapping.hostPort)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                        }

                        Image(systemName: "arrow.right")
                            .foregroundStyle(.secondary)
                            .padding(.top, 16)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Container")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            TextField("80", text: $mapping.containerPort)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Protocol")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Picker("Protocol", selection: $mapping.protocolName) {
                                Text("tcp").tag("tcp")
                                Text("udp").tag("udp")
                            }
                            .labelsHidden()
                            .frame(width: 72)
                        }

                        Spacer()

                        Button(role: .destructive) {
                            portMappings.removeAll { $0.id == mapping.id }
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                        .padding(.top, 16)
                    }
                    .padding(10)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct VolumeMountsEditor: View {
    @Binding var volumeMounts: [VolumeMount]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Volume mounts")
                    .font(.headline)
                Spacer()
                Button {
                    volumeMounts.append(VolumeMount())
                } label: {
                    Label("Add mount", systemImage: "plus")
                }
            }

            Text("Bind a folder from your Mac into the container.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if volumeMounts.isEmpty {
                Text("No volumes mounted.")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 8)
            } else {
                ForEach($volumeMounts) { $mount in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Host path")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                HStack {
                                    TextField(VolumeMountPaths.expandedDefaultDataDirectory, text: $mount.hostPath)
                                        .textFieldStyle(.roundedBorder)
                                    PathBrowseButton(
                                        path: $mount.hostPath,
                                        allowsDirectories: true,
                                        allowsFiles: false,
                                        defaultDirectory: VolumeMountPaths.defaultDataDirectoryURL
                                    )
                                }
                            }

                            Image(systemName: "arrow.right")
                                .foregroundStyle(.secondary)
                                .padding(.top, 16)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Container path")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                TextField("/app", text: $mount.containerPath)
                                    .textFieldStyle(.roundedBorder)
                            }
                        }

                        HStack {
                            Toggle("Read-only", isOn: $mount.readOnly)
                                .toggleStyle(.checkbox)
                            Spacer()
                            Button(role: .destructive) {
                                volumeMounts.removeAll { $0.id == mount.id }
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    .padding(10)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct EnvVariablesEditor: View {
    @Binding var envVars: [EnvVariable]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Environment")
                    .font(.headline)
                Spacer()
                Button {
                    envVars.append(EnvVariable())
                } label: {
                    Label("Add variable", systemImage: "plus")
                }
            }

            if envVars.isEmpty {
                Text("No environment variables.")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 8)
            } else {
                ForEach($envVars) { $variable in
                    HStack(spacing: 8) {
                        TextField("KEY", text: $variable.key)
                            .textFieldStyle(.roundedBorder)
                            .frame(minWidth: 120)
                        Text("=")
                            .foregroundStyle(.secondary)
                        TextField("value", text: $variable.value)
                            .textFieldStyle(.roundedBorder)
                        Button(role: .destructive) {
                            envVars.removeAll { $0.id == variable.id }
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct PathBrowseButton: View {
    @Binding var path: String
    var allowsDirectories = true
    var allowsFiles = true
    var title = "Browse…"
    var defaultDirectory: URL?

    var body: some View {
        Button(title) {
            let panel = NSOpenPanel()
            panel.canChooseFiles = allowsFiles
            panel.canChooseDirectories = allowsDirectories
            panel.allowsMultipleSelection = false
            panel.canCreateDirectories = true
            panel.prompt = "Choose"
            if let defaultDirectory {
                panel.directoryURL = defaultDirectory
            } else if !path.isEmpty {
                let expanded = (path as NSString).expandingTildeInPath
                panel.directoryURL = URL(fileURLWithPath: expanded, isDirectory: true)
            }
            if panel.runModal() == .OK, let url = panel.url {
                path = url.path
            }
        }
    }
}

struct ContainerFormFields: View {
    @Binding var form: CreateContainerForm
    var showPresetPicker = true
    var showCommand = true
    var lockName = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if showPresetPicker {
                LeftAlignedGroupBox("Templates") {
                    ImagePresetPicker(form: $form)
                }
            }

            LeftAlignedGroupBox("Image") {
                VStack(alignment: .leading, spacing: 16) {
                    FormTextField(
                        title: "Image",
                        help: "Docker-style image reference pulled from a registry or local store.",
                        placeholder: "alpine:latest",
                        text: $form.image,
                        isRequired: true
                    )

                    FormTextField(
                        title: "Name",
                        help: "Optional friendly name used as the container ID.",
                        placeholder: "my-web-server",
                        text: $form.name
                    )
                    .disabled(lockName)

                    if showCommand {
                        FormTextField(
                            title: "Command",
                            help: "Optional override. Leave empty to use the image default entrypoint.",
                            placeholder: "Leave empty for image default",
                            text: $form.command
                        )
                    }
                }
            }

            LeftAlignedGroupBox("Resources") {
                VStack(alignment: .leading, spacing: 16) {
                    FormTextField(
                        title: "CPUs",
                        help: "Virtual CPU limit. Leave empty for no limit.",
                        placeholder: "no limit",
                        text: $form.cpus
                    )

                    FormTextField(
                        title: "Memory",
                        help: "RAM limit with K, M, G suffix. Leave empty for no limit.",
                        placeholder: "no limit",
                        text: $form.memory
                    )

                    FormTextField(
                        title: "Working directory",
                        help: "Initial directory inside the container. Leave empty to use the image default.",
                        placeholder: "image default",
                        text: $form.workdir
                    )
                }
            }

            LeftAlignedGroupBox("Networking & Storage") {
                VStack(alignment: .leading, spacing: 20) {
                    PortMappingsEditor(portMappings: $form.portMappings)
                    Divider()
                    VolumeMountsEditor(volumeMounts: $form.volumeMounts)
                    Divider()
                    EnvVariablesEditor(envVars: $form.envVars)
                }
            }
        }
    }
}
