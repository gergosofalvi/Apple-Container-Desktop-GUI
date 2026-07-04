import SwiftUI

struct ImportComposeSheet: View {
    @Environment(AppViewModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    let serviceNames: [String]

    @State private var selectedServiceName: String

    init(serviceNames: [String]) {
        self.serviceNames = serviceNames
        _selectedServiceName = State(initialValue: serviceNames.first ?? "")
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("This compose file contains multiple services. Choose one to import into the create form.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Picker("Service", selection: $selectedServiceName) {
                    ForEach(serviceNames, id: \.self) { name in
                        Text(name).tag(name)
                    }
                }
                .pickerStyle(.radioGroup)

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
                    Button("Import") {
                        model.applyComposeImport(serviceName: selectedServiceName)
                        dismiss()
                    }
                    .disabled(selectedServiceName.isEmpty)
                }
            }
        }
        .frame(minWidth: 420, minHeight: 260)
    }
}
