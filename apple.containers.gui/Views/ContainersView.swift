import SwiftUI
import AppKit

struct ContainerListPanel: View {
    @Environment(AppViewModel.self) private var model
    @State private var showCLIHelp = false

    var body: some View {
        @Bindable var model = model

        List(selection: $model.selectedContainerID) {
            if model.containers.isEmpty {
                ContentUnavailableView {
                    Label("No Containers", systemImage: "shippingbox")
                } description: {
                    Text("Run a container to see it here.")
                }
            } else {
                ForEach(model.containerGroups) { group in
                    Section {
                        ForEach(model.containers(in: group)) { container in
                            ContainerListRow(container: container)
                                .tag(container.id)
                        }
                    } header: {
                        ContainerGroupHeader(
                            group: group,
                            containerCount: model.containers(in: group).count
                        )
                    }
                }

                if !model.ungroupedContainers.isEmpty {
                    Section {
                        ForEach(model.ungroupedContainers) { container in
                            ContainerListRow(container: container)
                                .tag(container.id)
                        }
                    } header: {
                        Text(model.containerGroups.isEmpty ? "Containers" : "Ungrouped")
                    }
                }
            }
        }
        .navigationTitle("Containers")
        .toolbar {
            ToolbarItemGroup {
                Button {
                    showCLIHelp = true
                } label: {
                    Label("CLI Help", systemImage: "questionmark.circle")
                }
                Button {
                    model.prepareCreateGroupSheet()
                } label: {
                    Label("Create Group", systemImage: "square.stack.3d.up")
                }
                Button {
                    model.importContainerCompose()
                } label: {
                    Label("Import", systemImage: "square.and.arrow.down")
                }
                Button {
                    model.prepareCreateContainerSheet()
                } label: {
                    Label("Run", systemImage: "plus")
                }
                ToolbarRefreshButton(isLoading: model.isLoading) {
                    Task { await model.refreshAll() }
                }
            }
        }
        .sheet(isPresented: $showCLIHelp) {
            ContainerCLIReferenceView()
                .frame(minWidth: 520, minHeight: 420)
        }
        .sheet(isPresented: $model.showManageGroup) {
            ManageGroupSheet()
        }
    }
}

struct ContainerListRow: View {
    @Environment(AppViewModel.self) private var model
    let container: ContainerRecord

    var body: some View {
        let display = model.containerDisplayStatus(for: container.id)

        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(model.containerDisplayName(for: container))
                    .font(.headline)
                    .lineLimit(1)
                    .layoutPriority(1)

                Spacer(minLength: 4)

                StatusBadge(
                    status: display.label,
                    isRunning: display.isRunning,
                    isTransitioning: display.isTransitioning
                )
                .fixedSize()
            }

            Text(container.networkAddressDisplay)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .lineLimit(1)

            Text(container.imageReference)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .help(container.imageReference)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 2)
    }
}

struct MachineListPanel: View {
    @Environment(AppViewModel.self) private var model
    @State private var showCLIHelp = false

    var body: some View {
        @Bindable var model = model

        List(selection: $model.selectedMachineID) {
            if model.machines.isEmpty {
                ContentUnavailableView {
                    Label("No Machines", systemImage: "desktopcomputer")
                } description: {
                    Text("Create a container machine to get started.")
                }
            } else {
                ForEach(model.machines, id: \.displayID) { machine in
                    MachineListRow(machine: machine)
                        .tag(machine.displayID)
                }
            }
        }
        .navigationTitle("Machines")
        .toolbar {
            ToolbarItemGroup {
                Button {
                    showCLIHelp = true
                } label: {
                    Label("CLI Help", systemImage: "questionmark.circle")
                }
                Button {
                    model.prepareCreateMachineSheet()
                } label: {
                    Label("Create", systemImage: "plus")
                }
                ToolbarRefreshButton(isLoading: model.isLoading) {
                    Task { await model.refreshAll() }
                }
            }
        }
        .sheet(isPresented: $showCLIHelp) {
            MachineCLIReferenceView()
                .frame(minWidth: 520, minHeight: 460)
        }
    }
}

struct MachineListRow: View {
    @Environment(AppViewModel.self) private var model
    let machine: MachineRecord

    var body: some View {
        let display = model.machineDisplayStatus(for: machine.displayID)

        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(machine.displayID)
                        .font(.headline)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    if machine.isDefault {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                            .help("Default machine")
                    }
                }

                Text(machine.imageReference)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)

            StatusBadge(
                status: display.label,
                isRunning: display.isRunning,
                isTransitioning: display.isTransitioning
            )
            .fixedSize()
            .layoutPriority(0)
        }
    }
}

struct ContainerDetailView: View {
    @Environment(AppViewModel.self) private var model
    let container: ContainerRecord

    @State private var inspectData: ContainerRecord?

    var body: some View {
        @Bindable var model = model
        let record = inspectData ?? container
        let display = model.containerDisplayStatus(for: record.id)
        let stack = model.containerGroup(for: record.id)

        ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    DetailHeaderView(
                        title: model.containerDisplayName(for: record),
                        subtitle: record.networkAddressDisplay,
                        status: display.label,
                        isRunning: display.isRunning,
                        isTransitioning: display.isTransitioning,
                        badge: stack?.name
                    )

                    ContainerActionButtons(
                        containerID: record.id,
                        isRunning: record.isRunning,
                        isTransitioning: display.isTransitioning
                    )

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        InfoCard(title: "Image", value: record.imageReference, icon: "shippingbox")
                        InfoCard(title: "Network name", value: record.networkHostName, icon: "network")
                        InfoCard(title: "IP address", value: record.networkAddressDisplay, icon: "number")
                        InfoCard(title: "Platform", value: record.platformDisplay, icon: "cpu")
                        InfoCard(title: "Resources", value: "\(record.cpusDisplay) CPU · \(record.memoryDisplay)", icon: "memorychip")
                        InfoCard(title: "Command", value: record.commandDisplay, icon: "terminal")
                        InfoCard(
                            title: "Networks",
                            value: record.networkNames.isEmpty ? "—" : record.networkNames.joined(separator: ", "),
                            icon: "network"
                        )
                    }

                    if let ports = record.configuration?.publish, !ports.isEmpty {
                        PublishedPortsSection(ports: ports)
                    }

                    LeftAlignedGroupBox("Network") {
                        VStack(alignment: .leading, spacing: 8) {
                            DetailRow(label: "Container name", value: record.networkHostName)
                            DetailRow(label: "IP address", value: record.networkAddressDisplay)
                            if let hostAccess = record.hostAccessSummary {
                                DetailRow(label: "From macOS", value: hostAccess)
                            }
                            Text("Containers on the same network can use the short name in env vars (for example WORDPRESS_DB_HOST=db). If that fails, use the peer IP shown below.")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            let peers = model.networkPeers(for: record.id)
                            if !peers.isEmpty {
                                Divider()
                                Text("Stack peers")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                ForEach(peers) { peer in
                                    DetailRow(
                                        label: peer.networkName,
                                        value: peer.ipv4Address.map { "\($0) (recommended for env vars)" } ?? "IP unavailable"
                                    )
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if !record.bindMountDisplays.isEmpty {
                        CompactListSection(title: "Bind mounts", icon: "folder", items: record.bindMountDisplays)
                    }

                    if !record.namedVolumeDisplays.isEmpty {
                        CompactListSection(title: "Named volumes", icon: "externaldrive", items: record.namedVolumeDisplays)
                    }

                    LeftAlignedGroupBox("Advanced details") {
                        VStack(alignment: .leading, spacing: 8) {
                            DetailRow(label: "Image digest", value: record.imageDigestDisplay)
                            DetailRow(label: "Workdir", value: record.workdir ?? "—")

                            if let stack {
                                DetailRow(label: "Group", value: stack.name)
                                DetailRow(label: "Group network", value: stack.networkName)
                                if let source = stack.sourceFile {
                                    DetailRow(label: "Source file", value: source)
                                }
                            } else if let source = record.sourceFileDisplay {
                                DetailRow(label: "Source file", value: source)
                            }

                            if let networks = record.networks, !networks.isEmpty {
                                ForEach(Array(networks.enumerated()), id: \.offset) { _, network in
                                    let address = [network.address, network.gateway]
                                        .compactMap { $0 }
                                        .filter { !$0.isEmpty }
                                        .joined(separator: " · gateway ")
                                    DetailRow(
                                        label: network.network ?? "Network",
                                        value: address.isEmpty ? "—" : address
                                    )
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task(id: container.id) {
            do {
                inspectData = try await model.fetchInspect(for: container.id)
            } catch {
                model.reportError(from: error.localizedDescription)
            }
        }
    }
}

private struct InfoCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout)
                .lineLimit(2)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct PublishedPortsSection: View {
    let ports: [PublishPort]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Ports", systemImage: "arrow.left.arrow.right")
                .font(.subheadline.weight(.semibold))

            ForEach(Array(ports.enumerated()), id: \.offset) { _, port in
                PublishedPortRow(port: port)
            }
        }
    }
}

struct PublishedPortRow: View {
    let port: PublishPort

    var body: some View {
        HStack(spacing: 10) {
            Text(port.description)
                .font(.system(.callout, design: .monospaced))
                .textSelection(.enabled)

            Spacer(minLength: 8)

            if let url = port.browserURL, let label = port.browserAddressLabel {
                Link(label, destination: url)
                    .font(.callout)
                    .help("Open \(url.absoluteString) in browser")

                Button {
                    NSWorkspace.shared.open(url)
                } label: {
                    Label("Open", systemImage: "safari")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
                .help("Open \(url.absoluteString) in browser")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

private struct CompactListSection: View {
    let title: String
    let icon: String
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.semibold))
            ForEach(items, id: \.self) { item in
                Text(item)
                    .font(.callout)
                    .textSelection(.enabled)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
    }
}
