import SwiftUI

struct ImportComposeSheet: View {
    @Environment(AppViewModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    let serviceNames: [String]

    @State private var selectedServiceName: String
    @State private var stackName: String
    @State private var stackNetworkName = "default"

    init(serviceNames: [String]) {
        self.serviceNames = serviceNames
        _selectedServiceName = State(initialValue: serviceNames.first ?? "")
        let defaultStackName = serviceNames.first?.replacingOccurrences(of: "-", with: " ") ?? "Stack"
        _stackName = State(initialValue: defaultStackName.capitalized)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("This compose file contains multiple services. Import one into the create form, or deploy the full stack as a grouped set of containers.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                GroupBox("Import One Service") {
                    Picker("Service", selection: $selectedServiceName) {
                        ForEach(serviceNames, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }
                    .pickerStyle(.radioGroup)
                }

                GroupBox("Deploy Full Stack") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Runs all \(serviceNames.count) services and groups them together like Docker Compose.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        TextField("Stack name", text: $stackName)
                            .textFieldStyle(.roundedBorder)

                        NetworkPicker(
                            title: "Network",
                            help: "All stack services are recreated on this network.",
                            networkName: $stackNetworkName,
                            networks: model.networks
                        )

                        Text("Services: \(serviceNames.joined(separator: ", "))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Spacer()
            }
            .padding(24)
            .navigationTitle("Import Compose")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        model.cancelComposeImport()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Menu("Import") {
                        Button("One Service") {
                            model.applyComposeImport(serviceName: selectedServiceName)
                            dismiss()
                        }
                        .disabled(selectedServiceName.isEmpty)

                        Button("Full Stack") {
                            Task {
                                await model.importComposeStack(
                                    named: stackName,
                                    networkName: stackNetworkName
                                )
                                dismiss()
                            }
                        }
                        .disabled(stackName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    } primaryAction: {
                        model.applyComposeImport(serviceName: selectedServiceName)
                        dismiss()
                    }
                    .disabled(selectedServiceName.isEmpty)
                }
            }
        }
        .frame(minWidth: 480, minHeight: 420)
        .onAppear {
            if let source = model.composeImportSourceName {
                let base = (source as NSString).deletingPathExtension
                stackName = base.replacingOccurrences(of: ".", with: " ").capitalized
            }
        }
        .task {
            await model.ensureResourceListsLoaded()
        }
    }
}
