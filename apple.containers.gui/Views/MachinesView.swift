import SwiftUI

struct MachineDetailView: View {
    @Environment(AppViewModel.self) private var model
    let machine: MachineRecord

    @State private var inspectData: MachineRecord?

    var body: some View {
        let record = inspectData ?? machine
        let display = model.machineDisplayStatus(for: record.displayID)

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                DetailHeaderView(
                    title: record.displayID,
                    subtitle: record.imageReference,
                    status: display.label,
                    isRunning: display.isRunning,
                    isTransitioning: display.isTransitioning,
                    badge: record.isDefault ? "DEFAULT" : nil
                )

                DetailActionBar {
                    IconActionButton(
                        title: "Shell",
                        systemImage: "terminal.fill",
                        tint: .purple
                    ) {
                        model.openSelectedMachineShell()
                    }
                    .disabled(display.isTransitioning)

                    if display.isTransitioning {
                        IconActionButton(
                            title: "Wait",
                            systemImage: "hourglass",
                            tint: .yellow,
                            disabled: true
                        ) {}
                    } else if record.isRunning {
                        IconActionButton(
                            title: "Stop",
                            systemImage: "stop.fill",
                            tint: .orange
                        ) {
                            Task { await model.stopSelectedMachine() }
                        }
                    }

                    if !record.isDefault {
                        IconActionButton(
                            title: "Default",
                            systemImage: "star.fill",
                            tint: .yellow
                        ) {
                            Task { await model.setDefaultSelectedMachine() }
                        }
                    }

                    IconActionButton(
                        title: "Delete",
                        systemImage: "trash.fill",
                        tint: .red,
                        role: .destructive
                    ) {
                        Task { await model.deleteSelectedMachine() }
                    }
                }

                GroupBox("Configuration") {
                    KeyValueGrid(rows: [
                        ("Status", display.label.capitalized),
                        ("Image", record.imageReference),
                        ("Platform", record.platformDisplay),
                        ("CPUs", record.cpusDisplay),
                        ("Memory", record.memoryDisplay),
                        ("Disk", record.diskSizeDisplay),
                        ("Home mount", record.homeMountDisplay),
                        ("IP address", record.ipAddressDisplay),
                        ("Created", record.createdDateDisplay),
                        ("User", record.userSetup?.username ?? "—"),
                    ])
                }

                GroupBox("CLI Commands") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Use container machine — not machine alone.")
                            .font(.callout)
                            .foregroundStyle(.orange)
                        Text(CLICommands.listMachines)
                            .font(.system(.caption, design: .monospaced))
                        Text(CLICommands.machineShellCommand(name: record.displayID))
                            .font(.system(.caption, design: .monospaced))
                    }
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox("About Container Machines") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Container machines run a full Linux environment with systemd support. Your macOS home directory is mounted inside, so you can edit on the Mac and build inside Linux.")
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("Open Shell runs: container machine run -n \(record.displayID)")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task(id: machine.displayID) {
            do {
                inspectData = try await model.fetchMachineInspect(for: machine.displayID)
            } catch {
                model.reportError(from: error.localizedDescription)
            }
        }
    }
}
