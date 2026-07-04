import Foundation

struct ContainerComposeService: Sendable, Equatable {
    var image: String
    var containerName: String?
    var workingDir: String?
    var ports: [String] = []
    var volumes: [String] = []
    var environment: [String: String] = [:]
    var command: String?
    var cpus: String?
    var memLimit: String?

    static func from(record: ContainerRecord) -> ContainerComposeService {
        var form = CreateContainerForm.from(record: record)
        form.command = commandLine(from: record)

        return ContainerComposeService(
            image: form.image,
            containerName: record.containerID,
            workingDir: form.workdir.nilIfEmpty,
            ports: form.portMappings.compactMap(\.composeValue),
            volumes: form.volumeMounts.compactMap(\.composeValue),
            environment: Dictionary(uniqueKeysWithValues: form.envVars.compactMap { env in
                guard let key = env.key.nilIfEmpty else { return nil }
                return (key, env.value)
            }),
            command: form.command.nilIfEmpty,
            cpus: form.cpus.nilIfEmpty,
            memLimit: form.memory.nilIfEmpty
        )
    }

    func toCreateContainerForm(serviceName: String) -> CreateContainerForm {
        var form = CreateContainerForm()
        form.image = image
        form.name = containerName ?? serviceName
        form.command = command ?? ""
        form.workdir = workingDir ?? ""
        form.cpus = cpus ?? ""
        form.memory = memLimit ?? ""
        form.portMappings = ports.compactMap { PortMapping.fromCompose($0) }
        form.volumeMounts = volumes.compactMap { VolumeMount.fromCompose($0) }
        form.envVars = environment
            .sorted { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }
            .map { EnvVariable(key: $0.key, value: $0.value) }
        return form
    }

    private static func commandLine(from record: ContainerRecord) -> String {
        guard let process = record.configuration?.process else { return "" }
        let executable = process.executable?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let args = process.args ?? []
        if executable.isEmpty {
            return args.joined(separator: " ")
        }
        return ([executable] + args).joined(separator: " ")
    }
}

struct ContainerComposeDocument: Sendable, Equatable {
    var services: [String: ContainerComposeService]

    static func from(record: ContainerRecord) -> ContainerComposeDocument {
        let key = ContainerComposeYAML.serviceKey(from: record.containerID)
        return ContainerComposeDocument(services: [key: .from(record: record)])
    }
}

enum ContainerComposeError: LocalizedError {
    case invalidFormat(String)
    case noServices
    case missingImage(String)

    var errorDescription: String? {
        switch self {
        case .invalidFormat(let detail):
            return "Invalid compose file: \(detail)"
        case .noServices:
            return "Compose file does not contain any services."
        case .missingImage(let service):
            return "Service '\(service)' is missing an image."
        }
    }
}

enum ContainerComposeYAML {
    static func encode(_ document: ContainerComposeDocument) -> String {
        var lines: [String] = [
            "# Exported by Apple Containers GUI",
            "# Docker Compose compatible format",
            "services:",
        ]

        let sortedServices = document.services.sorted { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }
        for (index, entry) in sortedServices.enumerated() {
            if index > 0 {
                lines.append("")
            }
            lines.append(contentsOf: encodeService(name: entry.key, service: entry.value))
        }

        return lines.joined(separator: "\n") + "\n"
    }

    static func decode(_ text: String) throws -> ContainerComposeDocument {
        let root = try parseMapping(text)

        guard let servicesNode = root["services"] else {
            throw ContainerComposeError.invalidFormat("Missing top-level 'services' section.")
        }

        let serviceMappings = try mappingValue(servicesNode, context: "services")
        guard !serviceMappings.isEmpty else {
            throw ContainerComposeError.noServices
        }

        var services: [String: ContainerComposeService] = [:]
        for (name, node) in serviceMappings {
            let mapping = try mappingValue(node, context: "service '\(name)'")
            let image = stringValue(mapping["image"])?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !image.isEmpty else {
                throw ContainerComposeError.missingImage(name)
            }

            services[name] = ContainerComposeService(
                image: image,
                containerName: stringValue(mapping["container_name"]),
                workingDir: stringValue(mapping["working_dir"]),
                ports: stringList(from: mapping["ports"]),
                volumes: stringList(from: mapping["volumes"]),
                environment: environmentMap(from: mapping["environment"]),
                command: commandString(from: mapping["command"]),
                cpus: stringValue(mapping["cpus"]),
                memLimit: stringValue(mapping["mem_limit"]) ?? stringValue(mapping["memory"])
            )
        }

        return ContainerComposeDocument(services: services)
    }

    static func serviceKey(from containerName: String) -> String {
        let lowered = containerName.lowercased()
        let sanitized = lowered.map { character -> Character in
            if character.isLetter || character.isNumber || character == "-" || character == "_" {
                return character
            }
            return "-"
        }
        let trimmed = String(sanitized).trimmingCharacters(in: CharacterSet(charactersIn: "-_"))
        return trimmed.isEmpty ? "container" : trimmed
    }

    private static func encodeService(name: String, service: ContainerComposeService) -> [String] {
        var lines = ["  \(yamlKey(name)):"]
        lines.append("    image: \(yamlQuote(service.image))")

        if let containerName = service.containerName?.nilIfEmpty {
            lines.append("    container_name: \(yamlQuote(containerName))")
        }
        if let workingDir = service.workingDir?.nilIfEmpty {
            lines.append("    working_dir: \(yamlQuote(workingDir))")
        }
        if let command = service.command?.nilIfEmpty {
            lines.append("    command: \(yamlQuote(command))")
        }
        if let cpus = service.cpus?.nilIfEmpty {
            lines.append("    cpus: \(yamlQuote(cpus))")
        }
        if let memLimit = service.memLimit?.nilIfEmpty {
            lines.append("    mem_limit: \(yamlQuote(memLimit))")
        }

        if !service.ports.isEmpty {
            lines.append("    ports:")
            for port in service.ports {
                lines.append("      - \(yamlQuote(port))")
            }
        }

        if !service.volumes.isEmpty {
            lines.append("    volumes:")
            for volume in service.volumes {
                lines.append("      - \(yamlQuote(volume))")
            }
        }

        if !service.environment.isEmpty {
            lines.append("    environment:")
            for key in service.environment.keys.sorted() {
                let value = service.environment[key] ?? ""
                lines.append("      \(yamlKey(key)): \(yamlQuote(value))")
            }
        }

        return lines
    }

    private static func yamlKey(_ value: String) -> String {
        if value.range(of: #"^[A-Za-z0-9_-]+$"#, options: .regularExpression) != nil {
            return value
        }
        return yamlQuote(value)
    }

    private static func yamlQuote(_ value: String) -> String {
        if value.isEmpty {
            return "\"\""
        }
        if value.range(of: #"^[A-Za-z0-9._/-]+$"#, options: .regularExpression) != nil {
            return value
        }
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }

    private enum YAMLNode {
        case scalar(String)
        case sequence([YAMLNode])
        case mapping([(String, YAMLNode)])
    }

    private static func parseMapping(_ text: String) throws -> [String: YAMLNode] {
        let lines = text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)

        var index = 0
        let nodes = try parseBlockLines(lines, start: &index, indent: -1)
        guard case .mapping(let pairs) = nodes else {
            throw ContainerComposeError.invalidFormat("Expected a YAML mapping at the top level.")
        }
        return Dictionary(uniqueKeysWithValues: pairs)
    }

    private static func parseBlockLines(_ lines: [String], start: inout Int, indent: Int) throws -> YAMLNode {
        var mapping: [(String, YAMLNode)] = []
        var sequence: [YAMLNode] = []

        while start < lines.count {
            let rawLine = lines[start]
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                start += 1
                continue
            }

            let lineIndent = rawLine.prefix(while: { $0 == " " }).count
            if lineIndent <= indent {
                break
            }

            if trimmed.hasPrefix("- ") {
                let itemText = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                start += 1

                if start < lines.count {
                    let nextLine = lines[start]
                    let nextTrimmed = nextLine.trimmingCharacters(in: .whitespaces)
                    let nextIndent = nextLine.prefix(while: { $0 == " " }).count
                    if !nextTrimmed.isEmpty, nextIndent > lineIndent, !nextTrimmed.hasPrefix("- ") {
                        let child = try parseBlockLines(lines, start: &start, indent: lineIndent)
                        if case .mapping(let pairs) = child, pairs.count == 1,
                           let only = pairs.first,
                           itemText.isEmpty || itemText == only.0 {
                            sequence.append(only.1)
                            continue
                        }
                        sequence.append(child)
                        continue
                    }
                }

                if itemText.hasPrefix("\"") || itemText.hasPrefix("'") {
                    sequence.append(.scalar(unquoteScalar(itemText)))
                } else if let keyValue = splitKeyValue(itemText),
                          keyValue.key.range(of: #"^[A-Za-z_][A-Za-z0-9_-]*$"#, options: .regularExpression) != nil {
                    sequence.append(.mapping([(keyValue.key, .scalar(keyValue.value))]))
                } else if !itemText.isEmpty {
                    sequence.append(.scalar(unquoteScalar(itemText)))
                }
                continue
            }

            guard let keyValue = splitKeyValue(trimmed) else {
                throw ContainerComposeError.invalidFormat("Unable to parse line: \(trimmed)")
            }

            start += 1
            if keyValue.value.isEmpty {
                if start < lines.count {
                    let nextLine = lines[start]
                    let nextTrimmed = nextLine.trimmingCharacters(in: .whitespaces)
                    let nextIndent = nextLine.prefix(while: { $0 == " " }).count
                    if !nextTrimmed.isEmpty, nextIndent > lineIndent {
                        let child = try parseBlockLines(lines, start: &start, indent: lineIndent)
                        mapping.append((keyValue.key, child))
                        continue
                    }
                }
                mapping.append((keyValue.key, .scalar("")))
            } else {
                mapping.append((keyValue.key, .scalar(unquoteScalar(keyValue.value))))
            }
        }

        if !sequence.isEmpty {
            return .sequence(sequence)
        }
        return .mapping(mapping)
    }

    private static func splitKeyValue(_ line: String) -> (key: String, value: String)? {
        guard let colonIndex = line.firstIndex(of: ":") else { return nil }
        let key = String(line[..<colonIndex]).trimmingCharacters(in: .whitespaces)
        let value = String(line[line.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty else { return nil }
        return (key, value)
    }

    private static func unquoteScalar(_ value: String) -> String {
        var trimmed = value.trimmingCharacters(in: .whitespaces)
        if (trimmed.hasPrefix("\"") && trimmed.hasSuffix("\"")) || (trimmed.hasPrefix("'") && trimmed.hasSuffix("'")) {
            trimmed = String(trimmed.dropFirst().dropLast())
        }
        return trimmed
            .replacingOccurrences(of: "\\\"", with: "\"")
            .replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "\\\\", with: "\\")
    }

    private static func mappingValue(_ node: YAMLNode, context: String) throws -> [String: YAMLNode] {
        guard case .mapping(let pairs) = node else {
            throw ContainerComposeError.invalidFormat("Expected a mapping for \(context).")
        }
        return Dictionary(uniqueKeysWithValues: pairs)
    }

    private static func stringValue(_ node: YAMLNode?) -> String? {
        guard case .scalar(let value) = node else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func stringList(from node: YAMLNode?) -> [String] {
        guard let node else { return [] }
        switch node {
        case .sequence(let items):
            return items.compactMap { item in
                switch item {
                case .scalar(let value):
                    return value.isEmpty ? nil : value
                case .mapping(let pairs):
                    if pairs.count == 1, case .scalar(let value) = pairs[0].1 {
                        return value.isEmpty ? nil : value
                    }
                    return nil
                case .sequence:
                    return nil
                }
            }
        case .scalar(let value):
            return value.isEmpty ? [] : [value]
        case .mapping:
            return []
        }
    }

    private static func environmentMap(from node: YAMLNode?) -> [String: String] {
        guard let node else { return [:] }
        switch node {
        case .mapping(let pairs):
            var result: [String: String] = [:]
            for (key, value) in pairs {
                if case .scalar(let scalar) = value {
                    result[key] = scalar
                }
            }
            return result
        case .sequence(let items):
            var result: [String: String] = [:]
            for item in items {
                guard case .scalar(let scalar) = item else { continue }
                let parts = scalar.split(separator: "=", maxSplits: 1).map(String.init)
                guard let key = parts.first, !key.isEmpty else { continue }
                result[key] = parts.count > 1 ? parts[1] : ""
            }
            return result
        case .scalar:
            return [:]
        }
    }

    private static func commandString(from node: YAMLNode?) -> String? {
        guard let node else { return nil }
        switch node {
        case .scalar(let value):
            return value.nilIfEmpty
        case .sequence(let items):
            let parts = items.compactMap { item -> String? in
                guard case .scalar(let value) = item else { return nil }
                return value.nilIfEmpty
            }
            return parts.isEmpty ? nil : parts.joined(separator: " ")
        case .mapping:
            return nil
        }
    }
}

private extension PortMapping {
    var composeValue: String? {
        guard let host = Int(hostPort.trimmingCharacters(in: .whitespaces)),
              let container = Int(containerPort.trimmingCharacters(in: .whitespaces)) else {
            return nil
        }
        let proto = protocolName.lowercased()
        if proto == "tcp" {
            return "\(host):\(container)"
        }
        return "\(host):\(container)/\(proto)"
    }

    static func fromCompose(_ value: String) -> PortMapping? {
        var trimmed = value.trimmingCharacters(in: .whitespaces)
        var proto = "tcp"
        if let slash = trimmed.lastIndex(of: "/") {
            proto = String(trimmed[trimmed.index(after: slash)...]).lowercased()
            trimmed = String(trimmed[..<slash])
        }

        let parts = trimmed.split(separator: ":").map(String.init)
        switch parts.count {
        case 2:
            return PortMapping(hostPort: parts[0], containerPort: parts[1], protocolName: proto)
        case 3:
            return PortMapping(hostPort: parts[1], containerPort: parts[2], protocolName: proto)
        default:
            return nil
        }
    }
}

private extension VolumeMount {
    var composeValue: String? {
        cliValue
    }

    static func fromCompose(_ value: String) -> VolumeMount? {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        if trimmed.hasSuffix(":ro") {
            let body = String(trimmed.dropLast(3))
            let parts = body.split(separator: ":", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { return nil }
            return VolumeMount(hostPath: parts[0], containerPath: parts[1], readOnly: true)
        }

        let parts = trimmed.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return nil }
        return VolumeMount(hostPath: parts[0], containerPath: parts[1], readOnly: false)
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
