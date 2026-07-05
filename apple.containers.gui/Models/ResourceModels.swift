import Foundation

struct VolumeRecord: Identifiable, Hashable, Sendable {
    let name: String
    let driver: String?
    let format: String?
    let sizeInBytes: Int64?
    let creationDate: String?
    let source: String?
    let labels: [String: String]?

    var id: String { name }

    var sizeDisplay: String {
        guard let sizeInBytes else { return "—" }
        return ByteCountFormatter.string(fromByteCount: sizeInBytes, countStyle: .file)
    }

    var creationDateDisplay: String {
        creationDate ?? "—"
    }
}

struct NetworkRecord: Identifiable, Hashable, Sendable {
    let name: String
    let plugin: String?
    let mode: String?
    let ipv4Subnet: String?
    let ipv4Gateway: String?
    let ipv6Subnet: String?
    let creationDate: String?
    let labels: [String: String]?

    var id: String { name }

    var creationDateDisplay: String {
        creationDate ?? "—"
    }

    var subnetDisplay: String {
        ipv4Subnet ?? ipv6Subnet ?? "—"
    }
}

struct ContainerGroup: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var name: String
    var networkName: String
    var memberContainerIDs: [String]
    var sourceFile: String?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        networkName: String = "default",
        memberContainerIDs: [String] = [],
        sourceFile: String? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.networkName = networkName
        self.memberContainerIDs = memberContainerIDs
        self.sourceFile = sourceFile
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        networkName = try container.decodeIfPresent(String.self, forKey: .networkName) ?? "default"
        memberContainerIDs = try container.decode([String].self, forKey: .memberContainerIDs)
        sourceFile = try container.decodeIfPresent(String.self, forKey: .sourceFile)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
    }
}

struct ManageGroupForm {
    var groupID: UUID?
    var name = ""
    var networkName = "default"
    var selectedContainerIDs: Set<String> = []

    mutating func reset(forCreate: Bool = true) {
        groupID = forCreate ? nil : groupID
        if forCreate {
            name = ""
            networkName = "default"
            selectedContainerIDs = []
        }
    }

    func validate(isCreate: Bool = true) -> String? {
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Group name is required."
        }
        if isCreate && selectedContainerIDs.isEmpty {
            return "Select at least one container for the group."
        }
        return nil
    }
}

struct CreateNetworkForm {
    var name = ""
    var subnet = ""
    var internalOnly = false

    mutating func reset() {
        self = CreateNetworkForm()
    }

    func validate() -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "Network name is required."
        }
        return nil
    }
}

struct CreateVolumeForm {
    var name = ""

    mutating func reset() {
        self = CreateVolumeForm()
    }

    func validate() -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "Volume name is required."
        }
        return nil
    }
}

enum ContainerResourceIndex {
    static func containers(usingVolume volumeName: String, in containers: [ContainerRecord]) -> [ContainerRecord] {
        containers.filter { $0.usesVolume(named: volumeName) }
    }

    static func containers(onNetwork networkName: String, in containers: [ContainerRecord]) -> [ContainerRecord] {
        containers.filter { $0.usesNetwork(named: networkName) }
    }
}

extension ContainerRecord {
    var allVolumeSources: [String] {
        let specs = (configuration?.mounts ?? []) + (configuration?.volumes ?? [])
        return specs.compactMap(\.source)
    }

    var networkNames: [String] {
        var names = Set<String>()
        networks?.compactMap(\.network).forEach { names.insert($0) }
        configuration?.networkNames?.forEach { names.insert($0) }
        return names.sorted()
    }

    func usesVolume(named volumeName: String) -> Bool {
        allVolumeSources.contains { source in
            source == volumeName
                || source.contains("/volumes/\(volumeName)/")
                || source.hasSuffix("/\(volumeName)/volume.img")
        }
    }

    func usesNetwork(named networkName: String) -> Bool {
        networkNames.contains(networkName)
    }
}
