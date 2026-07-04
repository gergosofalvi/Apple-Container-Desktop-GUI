import SwiftUI
import AppKit

struct CLIReferenceView: View {
    let title: String
    let commands: [(String, String)]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.title3.weight(.semibold))

            Text(CLICommands.macOSMachineWarning)
                .font(.callout)
                .foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(commands.enumerated()), id: \.offset) { _, item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.0)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack {
                            Text(item.1)
                                .font(.system(.body, design: .monospaced))
                                .textSelection(.enabled)
                            Spacer()
                            Button("Copy") {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(item.1, forType: .string)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }
}

struct ContainerCLIReferenceView: View {
    var body: some View {
        CLIReferenceView(
            title: "Container CLI",
            commands: [
                ("List running containers", CLICommands.listContainers),
                ("List all containers", CLICommands.listAllContainers),
                ("Run a container", "container run -d alpine:latest sleep infinity"),
                ("Exec into container (interactive sh)", "container exec -it CONTAINER_ID sh"),
                ("Exec run command", "container exec CONTAINER_ID sh -c \"ls -la\""),
                ("View logs", "container logs CONTAINER_ID"),
            ]
        )
    }
}

struct MachineCLIReferenceView: View {
    var body: some View {
        CLIReferenceView(
            title: "Container Machine CLI",
            commands: [
                ("List machines", CLICommands.listMachines),
                ("Short alias", CLICommands.machineAliasHint),
                ("Open shell", "container machine run -n MACHINE_NAME"),
                ("Run command", "container machine run -n dev uname -a"),
                ("Create machine", "container machine create alpine:latest --name dev"),
                ("Stop machine", "container machine stop MACHINE_NAME"),
            ]
        )
    }
}
