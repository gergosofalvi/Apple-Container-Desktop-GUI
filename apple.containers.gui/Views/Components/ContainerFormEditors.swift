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
    @Environment(AppViewModel.self) private var model
    @Binding var volumeMounts: [VolumeMount]
    var availableVolumes: [VolumeRecord] = []
    @State private var creatingVolumeID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Volume mounts")
                    .font(.headline)
                Spacer()
                Menu {
                    Button("Add bind mount") {
                        volumeMounts.append(VolumeMount(kind: .bind))
                    }
                    Button("Add named volume") {
                        volumeMounts.append(VolumeMount(kind: .named))
                    }
                } label: {
                    Label("Add mount", systemImage: "plus")
                }
            }

            Text("Bind a host folder or attach an existing named volume into the container.")
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
                        Picker("Type", selection: $mount.kind) {
                            ForEach(VolumeMount.Kind.allCases) { kind in
                                Text(kind.label).tag(kind)
                            }
                        }
                        .pickerStyle(.segmented)

                        HStack(spacing: 8) {
                            switch mount.kind {
                            case .bind:
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
                            case .named:
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Volume name")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    HStack(spacing: 8) {
                                        if !availableVolumes.isEmpty {
                                            Picker("Volume", selection: $mount.volumeName) {
                                                Text("Select or type…").tag("")
                                                ForEach(availableVolumes) { volume in
                                                    Text(volume.name).tag(volume.name)
                                                }
                                            }
                                            .labelsHidden()
                                            .frame(minWidth: 140)
                                        }
                                        TextField("my-volume", text: $mount.volumeName)
                                            .textFieldStyle(.roundedBorder)
                                        Button {
                                            Task {
                                                creatingVolumeID = mount.id
                                                let success = await model.createVolumeNamed(mount.volumeName)
                                                creatingVolumeID = nil
                                                if success {
                                                    mount.volumeName = mount.volumeName.trimmingCharacters(in: .whitespacesAndNewlines)
                                                }
                                            }
                                        } label: {
                                            if creatingVolumeID == mount.id {
                                                ProgressView()
                                                    .controlSize(.small)
                                            } else {
                                                Text("Create")
                                            }
                                        }
                                        .disabled(
                                            mount.volumeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                                || creatingVolumeID == mount.id
                                        )
                                    }
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

struct NetworkPicker: View {
    let title: String
    let help: String
    @Binding var networkName: String
    let networks: [NetworkRecord]
    var isDisabled = false

    private var networkOptions: [String] {
        var names = ["default"]
        for network in networks where !names.contains(network.name) {
            names.append(network.name)
        }
        if !names.contains(networkName), !networkName.isEmpty {
            names.append(networkName)
        }
        return names
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)

            Text(help)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            Picker("Network", selection: $networkName) {
                ForEach(networkOptions, id: \.self) { name in
                    Text(name).tag(name)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(maxWidth: 320, alignment: .leading)
            .disabled(isDisabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(isDisabled ? 0.75 : 1)
    }
}

struct ContainerGroupPicker: View {
    @Environment(AppViewModel.self) private var model
    @Binding var form: CreateContainerForm

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Group")
                .font(.headline)

            Text("Optionally add this container to a group. Existing groups lock the network to the group network.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Picker("Group mode", selection: $form.groupMode) {
                ForEach(CreateContainerGroupMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: form.groupMode) { _, newMode in
                applyGroupModeChange(newMode)
            }

            switch form.groupMode {
            case .none:
                EmptyView()
            case .existing:
                if model.containerGroups.isEmpty {
                    Text("No groups yet. Create one first or choose “Create new group”.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    Picker("Existing group", selection: $form.selectedExistingGroupID) {
                        Text("Select group…").tag(UUID?.none)
                        ForEach(model.containerGroups) { group in
                            Text(group.name).tag(Optional(group.id))
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(maxWidth: 320, alignment: .leading)
                    .onChange(of: form.selectedExistingGroupID) { _, groupID in
                        syncNetworkFromSelectedGroup(groupID)
                    }
                }
            case .new:
                FormTextField(
                    title: "New group name",
                    help: "A new group is created after the container starts.",
                    placeholder: "My Stack",
                    text: $form.newGroupName
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func applyGroupModeChange(_ mode: CreateContainerGroupMode) {
        switch mode {
        case .none:
            form.selectedExistingGroupID = nil
            form.newGroupName = ""
        case .existing:
            form.newGroupName = ""
            if form.selectedExistingGroupID == nil {
                form.selectedExistingGroupID = model.containerGroups.first?.id
            }
            syncNetworkFromSelectedGroup(form.selectedExistingGroupID)
        case .new:
            form.selectedExistingGroupID = nil
        }
    }

    private func syncNetworkFromSelectedGroup(_ groupID: UUID?) {
        guard let groupID,
              let group = model.containerGroups.first(where: { $0.id == groupID }) else {
            return
        }
        form.networkName = group.networkName
    }
}

struct ContainerFormFields: View {
    @Environment(AppViewModel.self) private var model
    @Binding var form: CreateContainerForm
    var showPresetPicker = true
    var showCommand = true
    var showGroupPicker = false
    var lockName = false

    private var networkHelp: String {
        if form.isNetworkLockedToGroup {
            return "Network is set by the selected group and cannot be changed here."
        }
        if form.groupMode == .new {
            return "Network used for this container and the new group."
        }
        return "Attach the container to an existing network. Default is used when no custom network is needed."
    }

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
                        help: "Container ID and network hostname. Other containers on the same network can reach this by this short name (for example db).",
                        placeholder: "db",
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
                    if showGroupPicker {
                        ContainerGroupPicker(form: $form)
                        Divider()
                    }

                    NetworkPicker(
                        title: "Network",
                        help: networkHelp,
                        networkName: $form.networkName,
                        networks: model.networks,
                        isDisabled: form.isNetworkLockedToGroup
                    )
                    Divider()
                    PortMappingsEditor(portMappings: $form.portMappings)
                    Divider()
                    VolumeMountsEditor(
                        volumeMounts: $form.volumeMounts,
                        availableVolumes: model.volumes
                    )
                    Divider()
                    EnvVariablesEditor(envVars: $form.envVars)
                }
            }
        }
    }
}
