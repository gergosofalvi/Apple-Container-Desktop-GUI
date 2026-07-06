import Foundation

struct ContainerRecord: Identifiable, Hashable, Sendable {
    let containerID: String
    let status: String?
    let networks: [ContainerNetwork]?
    let configuration: ContainerConfiguration?
    let image: ContainerImageRef?

    init(
        containerID: String,
        status: String? = nil,
        networks: [ContainerNetwork]? = nil,
        configuration: ContainerConfiguration? = nil,
        image: ContainerImageRef? = nil
    ) {
        self.containerID = containerID
        self.status = status
        self.networks = networks
        self.configuration = configuration
        self.image = image
    }

    var id: String { containerID }

    var displayName: String { containerID }

    var isRunning: Bool {
        status?.lowercased() == "running"
    }

    var memoryDisplay: String {
        guard let bytes = configuration?.resources?.memoryInBytes else { return "—" }
        return ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .memory)
    }

    var cpusDisplay: String {
        if let cpus = configuration?.resources?.cpus {
            return String(cpus)
        }
        return "—"
    }

    var mountPaths: [String] {
        bindMountDisplays
    }

    var volumePaths: [String] {
        namedVolumeDisplays
    }

    var bindMountDisplays: [String] {
        configuration?.mounts?.compactMap { mount in
            guard let target = mount.target, !target.isEmpty else { return nil }
            let source = mount.source ?? "?"
            let ro = mount.readonly == true ? " (ro)" : ""
            return "\(source) → \(target)\(ro)"
        } ?? []
    }

    var namedVolumeDisplays: [String] {
        configuration?.volumes?.compactMap { volume in
            guard let target = volume.target, !target.isEmpty else { return nil }
            let name = Self.volumeName(from: volume.source) ?? volume.source ?? "?"
            let ro = volume.readonly == true ? " (ro)" : ""
            return "\(name) → \(target)\(ro)"
        } ?? []
    }

    var platformDisplay: String {
        guard let platform = configuration?.platform else { return "—" }
        let os = platform.os ?? "linux"
        let arch = platform.architecture ?? "unknown"
        return "\(os)/\(arch)"
    }

    var imageDigestDisplay: String {
        configuration?.imageDigest ?? "—"
    }

    var sourceFileDisplay: String? {
        configuration?.labels?["com.apple.container.source"]
            ?? configuration?.labels?["compose.project"]
    }

    static func volumeName(from source: String?) -> String? {
        guard let source, !source.isEmpty else { return nil }
        if source.contains("/volumes/") {
            let parts = source.split(separator: "/")
            if let index = parts.firstIndex(of: "volumes"), index + 1 < parts.count {
                return String(parts[index + 1])
            }
        }
        if !source.contains("/") {
            return source
        }
        return nil
    }

    var publishedPorts: [String] {
        configuration?.publish?.map { port in
            if let host = port.hostPort, let container = port.containerPort {
                let proto = port.`protocol` ?? "tcp"
                return "\(host):\(container)/\(proto)"
            }
            return port.description
        } ?? []
    }

    var imageReference: String {
        image?.reference ?? image?.name ?? configuration?.image ?? "—"
    }

    var workdir: String? {
        configuration?.workdir
    }

    var commandDisplay: String {
        guard let process = configuration?.process else { return "—" }
        let parts = [process.executable].compactMap { $0 } + (process.args ?? [])
        let command = parts.joined(separator: " ")
        return command.isEmpty ? "—" : command
    }

    var ipv4Address: String? {
        networks?.compactMap { network -> String? in
            guard let address = network.address else { return nil }
            let host = address.split(separator: "/").first.map(String.init) ?? address
            return host.contains(".") ? host : nil
        }.first
    }

    var networkHostName: String {
        containerID
    }

    var networkAddressDisplay: String {
        ipv4Address ?? "—"
    }

    var hostAccessSummary: String? {
        guard let publish = configuration?.publish, !publish.isEmpty else { return nil }
        let entries = publish.compactMap { port -> String? in
            guard let hostPort = port.hostPort, let containerPort = port.containerPort else { return nil }
            let hostAddress = (port.hostIP?.isEmpty == false ? port.hostIP : nil) ?? "127.0.0.1"
            let proto = port.`protocol`?.uppercased() ?? "TCP"
            return "\(hostAddress):\(hostPort) → :\(containerPort)/\(proto)"
        }
        return entries.isEmpty ? nil : entries.joined(separator: ", ")
    }
}

struct NetworkPeerEndpoint: Hashable, Sendable, Identifiable {
    let containerID: String
    let networkName: String
    let ipv4Address: String?

    var id: String { containerID }

    var envValue: String {
        ipv4Address ?? networkName
    }
}

struct ContainerNetwork: Hashable, Sendable {
    let address: String?
    let gateway: String?
    let hostname: String?
    let network: String?
}

struct ContainerConfiguration: Hashable, Sendable {
    let id: String?
    let hostname: String?
    let image: String?
    let imageDigest: String?
    let platform: MachinePlatform?
    let workdir: String?
    let mounts: [MountSpec]?
    let volumes: [MountSpec]?
    let publish: [PublishPort]?
    let resources: ResourceSpec?
    let process: ProcessSpec?
    let labels: [String: String]?
    let env: [String]?
    let networkNames: [String]?
}

struct MountSpec: Hashable, Sendable {
    let type: String?
    let source: String?
    let target: String?
    let readonly: Bool?
}

struct PublishPort: Hashable, CustomStringConvertible, Sendable {
    let hostPort: Int?
    let containerPort: Int?
    let `protocol`: String?
    let hostIP: String?

    var description: String {
        let host = hostPort.map(String.init) ?? "*"
        let container = containerPort.map(String.init) ?? "?"
        let proto = `protocol` ?? "tcp"
        if let hostIP, !hostIP.isEmpty {
            return "\(hostIP):\(host):\(container)/\(proto)"
        }
        return "\(host):\(container)/\(proto)"
    }

    var browserHost: String {
        if let hostIP, !hostIP.isEmpty, hostIP != "0.0.0.0" {
            return hostIP
        }
        return "127.0.0.1"
    }

    var browserURL: URL? {
        guard let hostPort else { return nil }
        let proto = (`protocol` ?? "tcp").lowercased()
        guard proto == "tcp" else { return nil }

        let scheme: String
        if containerPort == 443 || hostPort == 443 {
            scheme = "https"
        } else {
            scheme = "http"
        }

        return URL(string: "\(scheme)://\(browserHost):\(hostPort)")
    }

    var browserAddressLabel: String? {
        guard let hostPort else { return nil }
        return "\(browserHost):\(hostPort)"
    }
}

struct ResourceSpec: Hashable, Sendable {
    let cpus: Double?
    let memoryInBytes: Int?
}

struct ProcessSpec: Hashable, Sendable {
    let args: [String]?
    let executable: String?
    let user: String?
}

struct ContainerImageRef: Hashable, Sendable {
    let reference: String?
    let name: String?
}

struct MachineImageRef: Hashable, Sendable {
    let reference: String?
}

struct MachinePlatform: Hashable, Sendable {
    let architecture: String?
    let os: String?
}

struct MachineUserSetup: Hashable, Sendable {
    let gid: Int?
    let uid: Int?
    let username: String?
}

struct MachineRecord: Identifiable, Hashable, Sendable {
    let machineID: String?
    let status: String?
    let createdDate: String?
    let cpus: Int?
    let memoryBytes: Int64?
    let diskSize: Int64?
    let defaultMachine: Bool?
    let homeMount: String?
    let ipAddress: String?
    let image: MachineImageRef?
    let platform: MachinePlatform?
    let userSetup: MachineUserSetup?

    init(
        machineID: String? = nil,
        status: String? = nil,
        createdDate: String? = nil,
        cpus: Int? = nil,
        memoryBytes: Int64? = nil,
        diskSize: Int64? = nil,
        defaultMachine: Bool? = nil,
        homeMount: String? = nil,
        ipAddress: String? = nil,
        image: MachineImageRef? = nil,
        platform: MachinePlatform? = nil,
        userSetup: MachineUserSetup? = nil
    ) {
        self.machineID = machineID
        self.status = status
        self.createdDate = createdDate
        self.cpus = cpus
        self.memoryBytes = memoryBytes
        self.diskSize = diskSize
        self.defaultMachine = defaultMachine
        self.homeMount = homeMount
        self.ipAddress = ipAddress
        self.image = image
        self.platform = platform
        self.userSetup = userSetup
    }

    var id: String { displayID }

    var displayID: String {
        machineID ?? "unknown"
    }

    var isRunning: Bool {
        status?.lowercased() == "running"
    }

    var isDefault: Bool {
        defaultMachine == true
    }

    var imageReference: String {
        image?.reference ?? "—"
    }

    var cpusDisplay: String {
        cpus.map(String.init) ?? "—"
    }

    var memoryDisplay: String {
        guard let memoryBytes else { return "—" }
        return ByteCountFormatter.string(fromByteCount: memoryBytes, countStyle: .memory)
    }

    var diskSizeDisplay: String {
        guard let diskSize else { return "—" }
        return ByteCountFormatter.string(fromByteCount: diskSize, countStyle: .file)
    }

    var homeMountDisplay: String {
        homeMount ?? "rw"
    }

    var platformDisplay: String {
        guard let platform else { return "—" }
        let os = platform.os ?? "linux"
        let arch = platform.architecture ?? "unknown"
        return "\(os)/\(arch)"
    }

    var ipAddressDisplay: String {
        ipAddress ?? "—"
    }

    var createdDateDisplay: String {
        createdDate ?? "—"
    }
}

enum SidebarSection: String, CaseIterable, Identifiable {
    case containers = "Containers"
    case volumes = "Volumes"
    case networks = "Networks"
    case machines = "Machines"
    case settings = "Settings"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .containers: "shippingbox"
        case .volumes: "externaldrive"
        case .networks: "network"
        case .machines: "desktopcomputer"
        case .settings: "gearshape"
        }
    }
}

enum VolumeMountError: LocalizedError {
    case notADirectory(String)

    var errorDescription: String? {
        switch self {
        case .notADirectory(let path):
            return "Bind mount host path is not a directory: \(path)"
        }
    }
}

struct CreateContainerForm {
    var image = "alpine:latest"
    var name = ""
    var command = ""
    var workdir = ""
    var cpus = ""
    var memory = ""
    var networkName = "default"
    var groupMode: CreateContainerGroupMode = .none
    var selectedExistingGroupID: UUID?
    var newGroupName = ""
    var portMappings: [PortMapping] = []
    var volumeMounts: [VolumeMount] = []
    var envVars: [EnvVariable] = []

    static var defaults: CreateContainerForm { CreateContainerForm() }

    mutating func reset() {
        self = Self.defaults
    }

    mutating func applyPreset(_ preset: ImagePreset) {
        image = preset.image
        command = preset.defaultCommand
        workdir = ""
        memory = preset.defaultMemory
        cpus = preset.defaultCPUs
        portMappings = preset.defaultPorts
        volumeMounts = preset.defaultVolumes.map { mount in
            var copy = mount
            copy.hostPath = VolumeMountPaths.resolvePresetHostPath(copy.hostPath)
            return copy
        }
        envVars = preset.defaultEnv
    }

    func validate() -> String? {
        if image.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Image is required. Example: alpine:latest or nginx:alpine"
        }
        switch groupMode {
        case .none:
            break
        case .existing:
            if selectedExistingGroupID == nil {
                return "Select a group or choose a different group option."
            }
        case .new:
            if newGroupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return "New group name is required."
            }
        }
        return nil
    }

    var isNetworkLockedToGroup: Bool {
        groupMode == .existing && selectedExistingGroupID != nil
    }

    func resolvedGroupName(existingGroups: [ContainerGroup]) -> String? {
        switch groupMode {
        case .none:
            return nil
        case .existing:
            guard let groupID = selectedExistingGroupID,
                  let group = existingGroups.first(where: { $0.id == groupID }) else {
                return nil
            }
            return group.name
        case .new:
            let trimmed = newGroupName.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
    }

    func displayNameForRegistry() -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func containerRunName() -> String? {
        let trimmed = displayNameForRegistry()
        return trimmed.isEmpty ? nil : trimmed
    }

    func ensureHostPathsExist() throws {
        let bindMounts = volumeMounts.filter { $0.kind == .bind }
        try VolumeMountPaths.ensureHostPathsExist(for: bindMounts)
    }

    func cliVolumes() -> [String] {
        volumeMounts.compactMap(\.cliValue)
    }

    func cliPorts() -> [String] {
        portMappings.compactMap(\.cliValue)
    }

    func cliEnv() -> [String] {
        envVars.compactMap(\.cliValue)
    }

    func commandParts() -> [String] {
        command
            .split(separator: " ")
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    static func from(record: ContainerRecord, groups: [ContainerGroup] = []) -> CreateContainerForm {
        var form = CreateContainerForm()
        let group = groups.first { $0.memberContainerIDs.contains(record.containerID) }

        form.image = record.imageReference
        form.command = ""
        form.workdir = record.workdir ?? ""
        form.cpus = cpusLine(from: record.configuration?.resources?.cpus)
        form.memory = memoryLine(from: record.configuration?.resources?.memoryInBytes)
        form.networkName = record.networkNames.first ?? "default"
        form.volumeMounts = volumeMounts(from: record.configuration)
        form.portMappings = portMappings(from: record.configuration?.publish)
        form.envVars = envVars(from: record.configuration?.env)
        form.name = record.containerID

        if let group {
            form.groupMode = .existing
            form.selectedExistingGroupID = group.id
        }

        return form
    }

    private static func cpusLine(from cpus: Double?) -> String {
        guard let cpus else { return "" }
        if cpus.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(cpus))
        }
        return String(cpus)
    }

    private static func memoryLine(from bytes: Int?) -> String {
        guard let bytes, bytes > 0 else { return "" }
        let units: [(Int, String)] = [
            (1_073_741_824, "G"),
            (1_048_576, "M"),
            (1_024, "K"),
        ]
        for (unit, suffix) in units where bytes >= unit && bytes % unit == 0 {
            return "\(bytes / unit)\(suffix)"
        }
        return String(bytes)
    }

    private static func volumeMounts(from configuration: ContainerConfiguration?) -> [VolumeMount] {
        var result: [VolumeMount] = []

        for mount in configuration?.mounts ?? [] {
            guard let target = mount.target, !target.isEmpty else { continue }
            result.append(
                VolumeMount(
                    kind: .bind,
                    hostPath: mount.source ?? "",
                    containerPath: target,
                    readOnly: mount.readonly == true
                )
            )
        }

        for volume in configuration?.volumes ?? [] {
            guard let target = volume.target, !target.isEmpty else { continue }
            let volumeName = ContainerRecord.volumeName(from: volume.source) ?? volume.source ?? ""
            result.append(
                VolumeMount(
                    kind: .named,
                    volumeName: volumeName,
                    containerPath: target,
                    readOnly: volume.readonly == true
                )
            )
        }

        return result
    }

    private static func portMappings(from ports: [PublishPort]?) -> [PortMapping] {
        guard let ports else { return [] }
        return ports.compactMap { port in
            guard let hostPort = port.hostPort, let containerPort = port.containerPort else { return nil }
            return PortMapping(
                hostPort: String(hostPort),
                containerPort: String(containerPort),
                protocolName: port.`protocol` ?? "tcp"
            )
        }
    }

    private static func envVars(from env: [String]?) -> [EnvVariable] {
        guard let env else { return [] }
        return env.compactMap { line in
            let parts = line.split(separator: "=", maxSplits: 1).map(String.init)
            guard let key = parts.first, !key.isEmpty else { return nil }
            return EnvVariable(key: key, value: parts.count > 1 ? parts[1] : "")
        }
    }
}

struct CreateMachineForm {
    var image = "alpine:latest"
    var name = "dev"
    var cpus = ""
    var memory = ""
    var homeMount = "rw"
    var setDefault = true

    static var defaults: CreateMachineForm { CreateMachineForm() }

    mutating func reset() {
        self = Self.defaults
    }

    func validate() -> String? {
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Machine name is required. Example: dev, ubuntu, kvm-dev"
        }
        if image.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Image is required. Example: alpine:latest or ubuntu:24.04"
        }
        return nil
    }
}
