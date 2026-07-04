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

                    ContainerFormFields(form: $model.createContainerForm)
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
