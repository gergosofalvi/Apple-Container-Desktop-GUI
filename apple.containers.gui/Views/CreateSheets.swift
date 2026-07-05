import SwiftUI

struct CreateContainerSheet: View {
    @Environment(AppViewModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var model = model

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    FormSectionHeader(
                        title: "Run Container",
                        subtitle: model.composeImportSourceName.map {
                            "Imported from \($0). Review settings, then run to create the container."
                        } ?? "Pick a template or configure ports, volumes, and environment visually."
                    )

                    if let error = model.createContainerError {
                        FormErrorBanner(
                            message: error,
                            terminalCommand: model.createContainerTerminalCommand
                        )
                    }

                    ContainerFormFields(form: $model.createContainerForm, showGroupPicker: true)
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("Run Container")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Run") {
                        Task { await model.createContainer() }
                    }
                    .disabled(model.isContainerRunInProgress)
                }
            }
        }
        .frame(minWidth: 640, minHeight: 760)
        .task {
            await model.ensureResourceListsLoaded()
        }
    }
}

struct EditContainerSheet: View {
    @Environment(AppViewModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var model = model

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    FormSectionHeader(
                        title: "Edit Container",
                        subtitle: "Update ports, volumes, and resources. The container command is preserved unless you override it."
                    )

                    LeftAlignedGroupBox("How this works") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("The container is stopped, removed, and recreated with updated settings.")
                                .font(.callout)
                            Text("Bind mounts and named volumes are preserved. The original command stays unless you fill the Command field.")
                                .font(.callout)
                                .foregroundStyle(.orange)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if let error = model.editContainerError {
                        FormErrorBanner(
                            message: error,
                            terminalCommand: model.editContainerTerminalCommand
                        )
                    }

                    ContainerFormFields(
                        form: $model.editContainerForm,
                        showPresetPicker: false,
                        showCommand: false,
                        lockName: true
                    )
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("Edit Container")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save & Restart") {
                        Task {
                            if await model.editContainer() {
                                dismiss()
                            }
                        }
                    }
                    .disabled(model.isLoading)
                }
            }
        }
        .frame(minWidth: 640, minHeight: 720)
        .task {
            await model.ensureResourceListsLoaded()
        }
    }
}

struct CreateMachineSheet: View {
    @Environment(AppViewModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    private let homeMountOptions = ["rw", "ro", "none"]

    var body: some View {
        @Bindable var model = model

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    FormSectionHeader(
                        title: "Create Machine",
                        subtitle: "A persistent Linux environment with systemd support. Your macOS home directory is mounted automatically."
                    )

                    if let error = model.createMachineError {
                        FormErrorBanner(
                            message: error,
                            terminalCommand: model.createMachineTerminalCommand
                        )
                    }

                    LeftAlignedGroupBox("Machine") {
                        VStack(alignment: .leading, spacing: 16) {
                            FormTextField(
                                title: "Name",
                                help: "Unique name used with container machine run -n.",
                                placeholder: "dev",
                                text: $model.createMachineForm.name,
                                isRequired: true
                            )

                            FormTextField(
                                title: "Image",
                                help: "Linux image with /sbin/init. Alpine is lightweight; Ubuntu works well with systemd.",
                                placeholder: "alpine:latest",
                                text: $model.createMachineForm.image,
                                isRequired: true
                            )

                            Toggle(isOn: $model.createMachineForm.setDefault) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Set as default machine")
                                        .font(.headline)
                                    Text("Default machine is used when -n is omitted in the CLI.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .toggleStyle(.switch)
                        }
                    }

                    LeftAlignedGroupBox("Resources") {
                        VStack(alignment: .leading, spacing: 16) {
                            FormTextField(
                                title: "CPUs",
                                help: "Virtual CPU count. Leave empty to use the CLI default.",
                                placeholder: "CLI default",
                                text: $model.createMachineForm.cpus
                            )

                            FormTextField(
                                title: "Memory",
                                help: "RAM allocation. Leave empty to use the CLI default (half of host memory).",
                                placeholder: "CLI default",
                                text: $model.createMachineForm.memory
                            )

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Home mount")
                                    .font(.headline)
                                Text("How your macOS home directory is exposed inside the machine.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.leading)

                                Picker("Home mount", selection: $model.createMachineForm.homeMount) {
                                    ForEach(homeMountOptions, id: \.self) { option in
                                        Text(option).tag(option)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .labelsHidden()
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("Create Machine")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task {
                            if await model.createMachine() {
                                dismiss()
                            }
                        }
                    }
                    .disabled(model.isLoading)
                }
            }
        }
        .frame(minWidth: 520, minHeight: 620)
    }
}

struct CreateVolumeSheet: View {
    @Environment(AppViewModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var model = model

        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                FormSectionHeader(
                    title: "Create Volume",
                    subtitle: "Named volumes persist data outside container lifecycle."
                )

                if let error = model.createVolumeError {
                    FormErrorBanner(message: error, terminalCommand: nil)
                }

                FormTextField(
                    title: "Volume name",
                    help: "Use a short name such as db-data or wordpress-content.",
                    placeholder: "my-volume",
                    text: $model.createVolumeForm.name
                )

                Spacer()
            }
            .padding(24)
            .navigationTitle("Create Volume")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task {
                            if await model.createVolume() {
                                dismiss()
                            }
                        }
                    }
                    .disabled(model.isLoading)
                }
            }
        }
        .frame(minWidth: 420, minHeight: 260)
    }
}

struct CreateNetworkSheet: View {
    @Environment(AppViewModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var model = model

        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                FormSectionHeader(
                    title: "Create Network",
                    subtitle: "Custom networks let containers communicate by name."
                )

                if let error = model.createNetworkError {
                    FormErrorBanner(message: error, terminalCommand: nil)
                }

                FormTextField(
                    title: "Network name",
                    help: "Example: wordpress-net",
                    placeholder: "my-network",
                    text: $model.createNetworkForm.name
                )

                FormTextField(
                    title: "IPv4 subnet",
                    help: "Optional. Example: 192.168.100.0/24",
                    placeholder: "Optional",
                    text: $model.createNetworkForm.subnet
                )

                Toggle("Host-only (internal)", isOn: $model.createNetworkForm.internalOnly)

                Spacer()
            }
            .padding(24)
            .navigationTitle("Create Network")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task {
                            if await model.createNetwork() {
                                dismiss()
                            }
                        }
                    }
                    .disabled(model.isLoading)
                }
            }
        }
        .frame(minWidth: 420, minHeight: 320)
    }
}

struct ManageGroupSheet: View {
    @Environment(AppViewModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    private var isEditing: Bool {
        model.manageGroupForm.groupID != nil
    }

    var body: some View {
        @Bindable var model = model

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    FormSectionHeader(
                        title: isEditing ? "Edit Group" : "Create Group",
                        subtitle: isEditing
                            ? "Change the group name, network, or membership. Added containers are recreated on the selected network."
                            : "Group existing containers and attach them to a shared network."
                    )

                    if let error = model.manageGroupError {
                        FormErrorBanner(message: error, terminalCommand: nil)
                    }

                    FormTextField(
                        title: "Group name",
                        help: "Display name for this container group.",
                        placeholder: "My Stack",
                        text: $model.manageGroupForm.name,
                        isRequired: true
                    )

                    NetworkPicker(
                        title: "Network",
                        help: "Containers added to the group are recreated on this network.",
                        networkName: $model.manageGroupForm.networkName,
                        networks: model.networks
                    )

                    LeftAlignedGroupBox("Containers") {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Select containers to include in this group.")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            if model.containers.isEmpty {
                                Text("No containers available.")
                                    .font(.callout)
                                    .foregroundStyle(.tertiary)
                            } else {
                                ForEach(model.containers) { container in
                                    let otherGroup = model.containerGroup(for: container.id)
                                    Toggle(isOn: binding(for: container.id)) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(container.displayName)
                                                .font(.subheadline.weight(.medium))
                                            Text(container.imageReference)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                            if let otherGroup, otherGroup.id != model.manageGroupForm.groupID {
                                                Text("Currently in \"\(otherGroup.name)\"")
                                                    .font(.caption2)
                                                    .foregroundStyle(.orange)
                                            }
                                        }
                                    }
                                    .toggleStyle(.checkbox)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if isEditing {
                        LeftAlignedGroupBox("Danger zone") {
                            Button("Delete Group", role: .destructive) {
                                if let groupID = model.manageGroupForm.groupID,
                                   let group = model.containerGroups.first(where: { $0.id == groupID }) {
                                    model.deleteContainerGroup(group)
                                    model.showManageGroup = false
                                    dismiss()
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle(isEditing ? "Edit Group" : "Create Group")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Create") {
                        Task {
                            if await model.saveManageGroup() {
                                dismiss()
                            }
                        }
                    }
                    .disabled(model.isLoading)
                }
            }
        }
        .frame(minWidth: 520, minHeight: 560)
        .task {
            await model.ensureResourceListsLoaded()
        }
    }

    private func binding(for containerID: String) -> Binding<Bool> {
        Binding(
            get: { model.manageGroupForm.selectedContainerIDs.contains(containerID) },
            set: { isSelected in
                if isSelected {
                    model.manageGroupForm.selectedContainerIDs.insert(containerID)
                } else {
                    model.manageGroupForm.selectedContainerIDs.remove(containerID)
                }
            }
        )
    }
}
