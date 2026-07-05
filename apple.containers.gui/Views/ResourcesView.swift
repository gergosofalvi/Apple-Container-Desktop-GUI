import SwiftUI

struct VolumeListPanel: View {
    @Environment(AppViewModel.self) private var model

    var body: some View {
        @Bindable var model = model

        List(selection: $model.selectedVolumeName) {
            if model.volumes.isEmpty {
                ContentUnavailableView {
                    Label("No Volumes", systemImage: "externaldrive")
                } description: {
                    Text("Named volumes appear here when containers use them.")
                }
            } else {
                ForEach(model.volumes) { volume in
                    VolumeListRow(volume: volume)
                        .tag(volume.name)
                }
            }
        }
        .navigationTitle("Volumes")
        .toolbar {
            ToolbarItemGroup {
                Button {
                    model.prepareCreateVolumeSheet()
                } label: {
                    Label("Create", systemImage: "plus")
                }
                ToolbarRefreshButton(isLoading: model.isLoading) {
                    Task { await model.refreshAll() }
                }
            }
        }
    }
}

struct VolumeListRow: View {
    @Environment(AppViewModel.self) private var model
    let volume: VolumeRecord

    var body: some View {
        let usageCount = model.containers(usingVolume: volume.name).count

        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(volume.name)
                    .font(.headline)
                    .lineLimit(1)

                Text(volume.driver ?? "local")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if usageCount > 0 {
                Text("\(usageCount) container\(usageCount == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("unused")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }
}

struct VolumeDetailView: View {
    @Environment(AppViewModel.self) private var model
    let volume: VolumeRecord

    @State private var inspectData: VolumeRecord?

    var body: some View {
        let record = inspectData ?? volume
        let linkedContainers = model.containers(usingVolume: record.name)

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                DetailHeaderView(
                    title: record.name,
                    subtitle: record.driver ?? "local",
                    status: linkedContainers.isEmpty ? "unused" : "in use",
                    isRunning: !linkedContainers.isEmpty
                )

                DetailActionBar {
                    IconActionButton(
                        title: "Delete",
                        systemImage: "trash.fill",
                        tint: .red,
                        role: .destructive
                    ) {
                        Task { await model.deleteSelectedVolume() }
                    }
                }

                GroupBox("Details") {
                    KeyValueGrid(rows: [
                        ("Driver", record.driver ?? "—"),
                        ("Format", record.format ?? "—"),
                        ("Size", record.sizeDisplay),
                        ("Created", record.creationDateDisplay),
                        ("Source", record.source ?? "—"),
                    ])
                }

                GroupBox("Used By") {
                    if linkedContainers.isEmpty {
                        Text("No containers are currently using this volume.")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(linkedContainers) { container in
                                Button {
                                    model.openContainerFromResource(container.id)
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(container.displayName)
                                                .font(.body.weight(.medium))
                                            Text(container.imageReference)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task(id: volume.name) {
            do {
                inspectData = try await model.fetchVolumeInspect(for: volume.name)
            } catch {
                model.reportError(from: error.localizedDescription)
            }
        }
    }
}

struct NetworkListPanel: View {
    @Environment(AppViewModel.self) private var model

    var body: some View {
        @Bindable var model = model

        List(selection: $model.selectedNetworkName) {
            if model.networks.isEmpty {
                ContentUnavailableView {
                    Label("No Networks", systemImage: "network")
                } description: {
                    Text("Create a network or run containers to see them here.")
                }
            } else {
                ForEach(model.networks) { network in
                    NetworkListRow(network: network)
                        .tag(network.name)
                }
            }
        }
        .navigationTitle("Networks")
        .toolbar {
            ToolbarItemGroup {
                Button {
                    model.prepareCreateNetworkSheet()
                } label: {
                    Label("Create", systemImage: "plus")
                }
                ToolbarRefreshButton(isLoading: model.isLoading) {
                    Task { await model.refreshAll() }
                }
            }
        }
    }
}

struct NetworkListRow: View {
    @Environment(AppViewModel.self) private var model
    let network: NetworkRecord

    var body: some View {
        let usageCount = model.containers(onNetwork: network.name).count

        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(network.name)
                    .font(.headline)
                    .lineLimit(1)

                Text(network.subnetDisplay)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text("\(usageCount) container\(usageCount == 1 ? "" : "s")")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct NetworkDetailView: View {
    @Environment(AppViewModel.self) private var model
    let network: NetworkRecord

    @State private var inspectData: NetworkRecord?

    var body: some View {
        let record = inspectData ?? network
        let linkedContainers = model.containers(onNetwork: record.name)
        let isBuiltin = record.labels?["com.apple.container.resource.role"] == "builtin"

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                DetailHeaderView(
                    title: record.name,
                    subtitle: record.plugin ?? "container-network-vmnet",
                    status: linkedContainers.isEmpty ? "idle" : "active",
                    isRunning: !linkedContainers.isEmpty,
                    badge: isBuiltin ? "BUILTIN" : nil
                )

                DetailActionBar {
                    IconActionButton(
                        title: "Delete",
                        systemImage: "trash.fill",
                        tint: .red,
                        role: .destructive,
                        disabled: isBuiltin
                    ) {
                        Task { await model.deleteSelectedNetwork() }
                    }
                }

                GroupBox("Details") {
                    KeyValueGrid(rows: [
                        ("Plugin", record.plugin ?? "—"),
                        ("Mode", record.mode ?? "—"),
                        ("IPv4 subnet", record.ipv4Subnet ?? "—"),
                        ("IPv4 gateway", record.ipv4Gateway ?? "—"),
                        ("IPv6 subnet", record.ipv6Subnet ?? "—"),
                        ("Created", record.creationDateDisplay),
                    ])
                }

                GroupBox("Connected Containers") {
                    if linkedContainers.isEmpty {
                        Text("No containers are connected to this network.")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(linkedContainers) { container in
                                Button {
                                    model.openContainerFromResource(container.id)
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(container.displayName)
                                                .font(.body.weight(.medium))
                                            Text(container.networkNames.joined(separator: ", "))
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task(id: network.name) {
            do {
                inspectData = try await model.fetchNetworkInspect(for: network.name)
            } catch {
                model.reportError(from: error.localizedDescription)
            }
        }
    }
}

struct ContainerGroupHeader: View {
    @Environment(AppViewModel.self) private var model
    let group: ContainerGroup
    let containerCount: Int

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "square.stack.3d.up.fill")
                .foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 1) {
                Text(group.name)
                    .font(.subheadline.weight(.semibold))
                HStack(spacing: 6) {
                    Text(group.networkName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    if let source = group.sourceFile {
                        Text("·")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Text(source)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            Spacer()
            Text("\(containerCount)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Button {
                model.prepareManageGroupSheet(group: group)
            } label: {
                Image(systemName: "pencil")
            }
            .buttonStyle(.borderless)
            .help("Edit group")
        }
    }
}
