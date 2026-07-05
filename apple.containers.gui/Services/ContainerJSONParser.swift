import Foundation

enum ContainerJSONParser {
    nonisolated static func parseContainerList(_ text: String) throws -> [ContainerRecord] {
        let items = try parseJSONArray(text)
        return items.map { containerRecord(from: $0) }
    }

    nonisolated static func parseContainerInspect(_ text: String) throws -> ContainerRecord {
        let items = try parseJSONArray(text)
        guard let first = items.first else {
            throw ContainerCLIError.invalidOutput("No inspect data returned for container.")
        }
        return containerRecord(from: first)
    }

    nonisolated static func parseMachineList(_ text: String) throws -> [MachineRecord] {
        let items = try parseJSONArray(text)
        return items.map { machineRecord(from: $0) }
    }

    nonisolated static func parseMachineInspect(_ text: String) throws -> MachineRecord {
        let items = try parseJSONArray(text)
        guard let first = items.first else {
            throw ContainerCLIError.invalidOutput("No inspect data returned for machine.")
        }
        return machineRecord(from: first)
    }

    nonisolated private static func containerRecord(from dict: [String: Any]) -> ContainerRecord {
        let config = dict["configuration"] as? [String: Any]
        let status = dict["status"] as? [String: Any]

        let containerID = stringValue(dict["id"])
            ?? stringValue(config?["id"])
            ?? "unknown"

        let state = stringValue(status?["state"])
        let networks = containerNetworks(from: status?["networks"])
        let configuration = containerConfiguration(from: config)
        let image = containerImageRef(from: config?["image"])

        return ContainerRecord(
            containerID: containerID,
            status: state,
            networks: networks,
            configuration: configuration,
            image: image
        )
    }

    nonisolated private static func containerConfiguration(from config: [String: Any]?) -> ContainerConfiguration? {
        guard let config else { return nil }

        let initProcess = config["initProcess"] as? [String: Any]
        let resources = config["resources"] as? [String: Any]
        let imageReference = containerImageRef(from: config["image"])?.reference

        return ContainerConfiguration(
            id: stringValue(config["id"]),
            hostname: networkHostname(from: config["networks"]),
            image: imageReference,
            imageDigest: imageDigest(from: config["image"]),
            platform: platform(from: config["platform"]),
            workdir: stringValue(initProcess?["workingDirectory"]),
            mounts: mountSpecs(from: config["mounts"]),
            volumes: mountSpecs(from: config["volumes"]),
            publish: publishPorts(from: config["publishedPorts"]),
            resources: resourceSpec(from: resources),
            process: processSpec(from: initProcess),
            labels: stringDictionary(from: config["labels"]),
            env: stringArray(from: initProcess?["environment"]),
            networkNames: networkNames(from: config["networks"])
        )
    }

    nonisolated static func parseVolumeList(_ text: String) throws -> [VolumeRecord] {
        let items = try parseJSONArray(text)
        return items.map { volumeRecord(from: $0) }
    }

    nonisolated static func parseVolumeInspect(_ text: String) throws -> VolumeRecord {
        let items = try parseJSONArray(text)
        guard let first = items.first else {
            throw ContainerCLIError.invalidOutput("No inspect data returned for volume.")
        }
        return volumeRecord(from: first)
    }

    nonisolated static func parseNetworkList(_ text: String) throws -> [NetworkRecord] {
        let items = try parseJSONArray(text)
        return items.map { networkRecord(from: $0) }
    }

    nonisolated static func parseNetworkInspect(_ text: String) throws -> NetworkRecord {
        let items = try parseJSONArray(text)
        guard let first = items.first else {
            throw ContainerCLIError.invalidOutput("No inspect data returned for network.")
        }
        return networkRecord(from: first)
    }

    nonisolated private static func volumeRecord(from dict: [String: Any]) -> VolumeRecord {
        let config = dict["configuration"] as? [String: Any]
        let name = stringValue(dict["id"])
            ?? stringValue(config?["name"])
            ?? "unknown"

        return VolumeRecord(
            name: name,
            driver: stringValue(config?["driver"]),
            format: stringValue(config?["format"]),
            sizeInBytes: int64Value(config?["sizeInBytes"]),
            creationDate: stringValue(config?["creationDate"]),
            source: stringValue(config?["source"]),
            labels: stringDictionary(from: config?["labels"])
        )
    }

    nonisolated private static func networkRecord(from dict: [String: Any]) -> NetworkRecord {
        let config = dict["configuration"] as? [String: Any]
        let status = dict["status"] as? [String: Any]
        let name = stringValue(dict["id"])
            ?? stringValue(config?["name"])
            ?? "unknown"

        return NetworkRecord(
            name: name,
            plugin: stringValue(config?["plugin"]),
            mode: stringValue(config?["mode"]),
            ipv4Subnet: stringValue(status?["ipv4Subnet"]),
            ipv4Gateway: stringValue(status?["ipv4Gateway"]),
            ipv6Subnet: stringValue(status?["ipv6Subnet"]),
            creationDate: stringValue(config?["creationDate"]),
            labels: stringDictionary(from: config?["labels"])
        )
    }

    nonisolated private static func networkNames(from value: Any?) -> [String]? {
        guard let array = value as? [[String: Any]], !array.isEmpty else { return nil }
        let names = array.compactMap { stringValue($0["network"]) }
        return names.isEmpty ? nil : names
    }

    nonisolated private static func stringDictionary(from value: Any?) -> [String: String]? {
        guard let dict = value as? [String: Any], !dict.isEmpty else { return nil }
        var result: [String: String] = [:]
        for (key, value) in dict {
            if let string = stringValue(value) {
                result[key] = string
            }
        }
        return result.isEmpty ? nil : result
    }

    nonisolated private static func containerNetworks(from value: Any?) -> [ContainerNetwork]? {
        guard let array = value as? [[String: Any]], !array.isEmpty else { return nil }
        return array.map { dict in
            ContainerNetwork(
                address: stringValue(dict["ipv4Address"]) ?? stringValue(dict["address"]),
                gateway: stringValue(dict["ipv4Gateway"]) ?? stringValue(dict["gateway"]),
                hostname: stringValue(dict["hostname"]),
                network: stringValue(dict["network"])
            )
        }
    }

    nonisolated private static func networkHostname(from value: Any?) -> String? {
        guard let array = value as? [[String: Any]],
              let first = array.first,
              let options = first["options"] as? [String: Any] else {
            return nil
        }
        return stringValue(options["hostname"])
    }

    nonisolated private static func mountSpecs(from value: Any?) -> [MountSpec]? {
        guard let array = value as? [[String: Any]], !array.isEmpty else { return nil }
        return array.map { dict in
            MountSpec(
                type: stringValue(dict["type"]),
                source: stringValue(dict["source"]),
                target: stringValue(dict["target"]),
                readonly: boolValue(dict["readonly"])
            )
        }
    }

    nonisolated private static func publishPorts(from value: Any?) -> [PublishPort]? {
        guard let array = value as? [[String: Any]], !array.isEmpty else { return nil }
        return array.map { dict in
            PublishPort(
                hostPort: intValue(dict["hostPort"]) ?? intValue(dict["host"]),
                containerPort: intValue(dict["containerPort"]) ?? intValue(dict["container"]),
                protocol: stringValue(dict["protocol"]),
                hostIP: stringValue(dict["hostIP"])
            )
        }
    }

    nonisolated private static func resourceSpec(from dict: [String: Any]?) -> ResourceSpec? {
        guard let dict else { return nil }
        return ResourceSpec(
            cpus: doubleValue(dict["cpus"]),
            memoryInBytes: intValue(dict["memoryInBytes"])
        )
    }

    nonisolated private static func processSpec(from dict: [String: Any]?) -> ProcessSpec? {
        guard let dict else { return nil }
        return ProcessSpec(
            args: stringArray(from: dict["arguments"]),
            executable: stringValue(dict["executable"]),
            user: nil
        )
    }

    nonisolated private static func containerImageRef(from value: Any?) -> ContainerImageRef? {
        guard let dict = value as? [String: Any],
              let reference = stringValue(dict["reference"]) else {
            return nil
        }
        return ContainerImageRef(reference: reference, name: nil)
    }

    nonisolated private static func imageDigest(from value: Any?) -> String? {
        guard let dict = value as? [String: Any],
              let descriptor = dict["descriptor"] as? [String: Any],
              let digest = stringValue(descriptor["digest"]) else {
            return nil
        }
        return digest
    }

    nonisolated private static func machineRecord(from dict: [String: Any]) -> MachineRecord {
        MachineRecord(
            machineID: stringValue(dict["id"]),
            status: stringValue(dict["status"]),
            createdDate: stringValue(dict["createdDate"]),
            cpus: intValue(dict["cpus"]),
            memoryBytes: int64Value(dict["memory"]),
            diskSize: int64Value(dict["diskSize"]),
            defaultMachine: boolValue(dict["default"]),
            homeMount: stringValue(dict["homeMount"]),
            ipAddress: stringValue(dict["ipAddress"]),
            image: machineImageRef(from: dict["image"]),
            platform: platform(from: dict["platform"]),
            userSetup: userSetup(from: dict["userSetup"])
        )
    }

    nonisolated private static func machineImageRef(from value: Any?) -> MachineImageRef? {
        guard let dict = value as? [String: Any],
              let reference = stringValue(dict["reference"]) else {
            return nil
        }
        return MachineImageRef(reference: reference)
    }

    nonisolated private static func platform(from value: Any?) -> MachinePlatform? {
        guard let dict = value as? [String: Any] else { return nil }
        return MachinePlatform(
            architecture: stringValue(dict["architecture"]),
            os: stringValue(dict["os"])
        )
    }

    nonisolated private static func userSetup(from value: Any?) -> MachineUserSetup? {
        guard let dict = value as? [String: Any] else { return nil }
        return MachineUserSetup(
            gid: intValue(dict["gid"]),
            uid: intValue(dict["uid"]),
            username: stringValue(dict["username"])
        )
    }

    nonisolated private static func parseJSONArray(_ text: String) throws -> [[String: Any]] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        guard let data = trimmed.data(using: .utf8) else {
            throw ContainerCLIError.invalidOutput("Unable to decode CLI output.")
        }

        let json = try JSONSerialization.jsonObject(with: data)
        if let array = json as? [[String: Any]] {
            return array
        }
        if let object = json as? [String: Any] {
            return [object]
        }

        throw ContainerCLIError.invalidOutput("Expected JSON array from container CLI.")
    }

    nonisolated private static func stringArray(from value: Any?) -> [String]? {
        guard let array = value as? [Any], !array.isEmpty else { return nil }
        let strings = array.compactMap { item -> String? in
            if let string = item as? String { return string }
            if let number = item as? NSNumber { return number.stringValue }
            return nil
        }
        return strings.isEmpty ? nil : strings
    }

    nonisolated private static func stringValue(_ value: Any?) -> String? {
        switch value {
        case let string as String:
            return string
        case let number as NSNumber:
            return number.stringValue
        default:
            return nil
        }
    }

    nonisolated private static func boolValue(_ value: Any?) -> Bool? {
        switch value {
        case let bool as Bool:
            return bool
        case let number as NSNumber:
            return number.boolValue
        default:
            return nil
        }
    }

    nonisolated private static func intValue(_ value: Any?) -> Int? {
        switch value {
        case let int as Int:
            return int
        case let int64 as Int64:
            return Int(exactly: int64)
        case let number as NSNumber:
            return number.intValue
        default:
            return nil
        }
    }

    nonisolated private static func int64Value(_ value: Any?) -> Int64? {
        switch value {
        case let int as Int:
            return Int64(int)
        case let int64 as Int64:
            return int64
        case let number as NSNumber:
            return number.int64Value
        default:
            return nil
        }
    }

    nonisolated private static func doubleValue(_ value: Any?) -> Double? {
        switch value {
        case let double as Double:
            return double
        case let int as Int:
            return Double(int)
        case let number as NSNumber:
            return number.doubleValue
        default:
            return nil
        }
    }
}
