import Foundation
import AppKit

enum ContainerCLIError: LocalizedError {
    case notInstalled
    case commandFailed(String)
    case invalidOutput(String)

    var errorDescription: String? {
        switch self {
        case .notInstalled:
            return "Apple Container CLI is not installed."
        case .commandFailed(let message):
            return message
        case .invalidOutput(let message):
            return message
        }
    }
}

struct ContainerCommandResult: Sendable {
    let stdout: String
    let stderr: String
    let exitCode: Int32

    nonisolated var combinedOutput: String {
        Self.makeCombinedOutput(stdout: stdout, stderr: stderr)
    }

    nonisolated static func makeCombinedOutput(stdout: String, stderr: String) -> String {
        [stdout, stderr]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }
}

actor ContainerCLI {
    static let shared = ContainerCLI()

    static let installPKGURL = URL(string: "https://github.com/apple/container/releases/download/1.0.0/container-1.0.0-installer-signed.pkg")!
    static let releasesURL = URL(string: "https://github.com/apple/container/releases")!

    private let searchPaths = [
        "/usr/local/bin",
        "/opt/homebrew/bin",
        "/usr/bin",
    ]

    private var cachedBinaryPath: String?

    func isInstalled() -> Bool {
        resolveBinaryPath() != nil
    }

    func resolveBinaryPath() -> String? {
        if let cachedBinaryPath {
            return cachedBinaryPath
        }

        for directory in searchPaths {
            let candidate = (directory as NSString).appendingPathComponent("container")
            if FileManager.default.isExecutableFile(atPath: candidate) {
                cachedBinaryPath = candidate
                return candidate
            }
        }

        if let path = runShell("command -v container")?.trimmingCharacters(in: .whitespacesAndNewlines),
           !path.isEmpty,
           FileManager.default.isExecutableFile(atPath: path) {
            cachedBinaryPath = path
            return path
        }

        return nil
    }

    func version() async throws -> String {
        let result = try await run(["--version"])
        let version = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        if version.isEmpty {
            throw ContainerCLIError.commandFailed(result.stderr.isEmpty ? "Unable to read version." : result.stderr)
        }
        return version
    }

    func ensureSystemRunning() async throws {
        let status = try await run(["system", "status", "--format", "json"])
        if status.exitCode != 0 {
            _ = try await run(["system", "start"])
        }
    }

    func listContainers(all: Bool = true) async throws -> [ContainerRecord] {
        var args = ["ls", "--format", "json"]
        if all {
            args.insert("--all", at: 1)
        }
        let result = try await run(args)
        return try ContainerJSONParser.parseContainerList(result.stdout)
    }

    func inspectContainer(id: String) async throws -> ContainerRecord {
        let result = try await run(["inspect", id])
        return try ContainerJSONParser.parseContainerInspect(result.stdout)
    }

    func inspectContainerRawJSON(id: String) async throws -> String {
        let result = try await run(["inspect", id])
        if result.exitCode != 0 {
            throw ContainerCLIError.commandFailed(result.stderr.isEmpty ? result.stdout : result.stderr)
        }
        return result.stdout
    }

    func containerLogs(id: String, lineCount: Int? = nil, follow: Bool = false) async throws -> String {
        var args = ["logs"]
        if follow {
            args.append("--follow")
        }
        if let lineCount {
            args += ["-n", String(lineCount)]
        }
        args.append(id)
        let result = try await run(args)
        if result.exitCode != 0 {
            throw ContainerCLIError.commandFailed(result.stderr.isEmpty ? result.stdout : result.stderr)
        }
        let combined = [result.stdout, result.stderr]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
        return combined
    }

    func execCommand(containerID: String, command: String) async throws -> String {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        let result = try await run(["exec", containerID, "sh", "-c", trimmed])
        let stdout = result.stdout
        let stderr = result.stderr
        var output = ""
        if !stdout.isEmpty { output += stdout }
        if !stderr.isEmpty {
            if !output.isEmpty, !output.hasSuffix("\n") { output += "\n" }
            output += stderr
        }
        if result.exitCode != 0, output.isEmpty {
            throw ContainerCLIError.commandFailed("Command failed with exit code \(result.exitCode)")
        }
        if result.exitCode != 0 {
            output += "\n[exit \(result.exitCode)]"
        }
        return output
    }

    func runContainer(
        image: String,
        name: String?,
        detach: Bool = true,
        command: [String] = [],
        volumes: [String] = [],
        ports: [String] = [],
        env: [String] = [],
        workdir: String? = nil,
        cpus: String? = nil,
        memory: String? = nil,
        network: String? = nil,
        onOutput: (@Sendable (String) -> Void)? = nil
    ) async throws -> String {
        let args = buildRunArguments(
            platform: nil,
            image: image,
            name: name,
            detach: detach,
            command: command,
            volumes: volumes,
            ports: ports,
            env: env,
            workdir: workdir,
            cpus: cpus,
            memory: memory,
            network: network
        )

        let result = try await runStreaming(args, onOutput: onOutput)
        if result.exitCode == 0 {
            return result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let failureOutput = result.combinedOutput
        guard Self.shouldRetryWithAMD64Emulation(failureOutput) else {
            throw ContainerCLIError.commandFailed(failureOutput.isEmpty ? "Container run failed." : failureOutput)
        }

        onOutput?("\nImage has no native arm64 variant. Pulling linux/amd64 and running with emulation...\n\n")

        let amd64Args = buildRunArguments(
            platform: Self.fallbackPlatform,
            image: image,
            name: name,
            detach: detach,
            command: command,
            volumes: volumes,
            ports: ports,
            env: env,
            workdir: workdir,
            cpus: cpus,
            memory: memory,
            network: network
        )

        let retryResult = try await runStreaming(amd64Args, onOutput: onOutput)
        if retryResult.exitCode == 0 {
            return retryResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let retryOutput = retryResult.combinedOutput
        throw ContainerCLIError.commandFailed(
            retryOutput.isEmpty ? "Container run failed after amd64 fallback." : retryOutput
        )
    }

    private static let fallbackPlatform = "linux/amd64"

    private static func shouldRetryWithAMD64Emulation(_ output: String) -> Bool {
        let normalized = output.lowercased()
        return normalized.contains("does not support required platforms")
            || normalized.contains("unsupported platform")
            || normalized.contains("unsupported: \"platform linux/arm64")
    }

    private func buildRunArguments(
        platform: String?,
        image: String,
        name: String?,
        detach: Bool,
        command: [String],
        volumes: [String],
        ports: [String],
        env: [String],
        workdir: String?,
        cpus: String?,
        memory: String?,
        network: String?
    ) -> [String] {
        var args = ["run"]
        if detach {
            args.append("-d")
        }
        if let platform, !platform.isEmpty {
            args += ["--platform", platform]
        }
        if let name, !name.isEmpty {
            args += ["--name", name]
        }
        if let network, !network.isEmpty {
            args += ["--network", network]
        }
        for volume in volumes where !volume.isEmpty {
            args += ["-v", volume]
        }
        for port in ports where !port.isEmpty {
            args += ["-p", port]
        }
        for variable in env where !variable.isEmpty {
            args += ["-e", variable]
        }
        if let workdir, !workdir.isEmpty {
            args += ["-w", workdir]
        }
        if let cpus, !cpus.isEmpty {
            args += ["-c", cpus]
        }
        if let memory, !memory.isEmpty {
            args += ["-m", memory]
        }
        args.append(image)
        args.append(contentsOf: command)
        return args
    }

    func stopContainer(id: String) async throws {
        let result = try await run(["stop", id])
        if result.exitCode != 0 {
            throw ContainerCLIError.commandFailed(result.stderr.isEmpty ? result.stdout : result.stderr)
        }
    }

    func startContainer(id: String) async throws {
        let result = try await run(["start", id])
        if result.exitCode != 0 {
            throw ContainerCLIError.commandFailed(result.stderr.isEmpty ? result.stdout : result.stderr)
        }
    }

    func deleteContainer(id: String, force: Bool = true) async throws {
        var args = ["rm"]
        if force {
            args.append("-f")
        }
        args.append(id)
        let result = try await run(args)
        if result.exitCode != 0 {
            throw ContainerCLIError.commandFailed(result.stderr.isEmpty ? result.stdout : result.stderr)
        }
    }

    func listVolumes() async throws -> [VolumeRecord] {
        let result = try await run(["volume", "ls", "--format", "json"])
        if result.exitCode != 0 {
            throw ContainerCLIError.commandFailed(result.combinedOutput)
        }
        return try ContainerJSONParser.parseVolumeList(result.stdout)
    }

    func inspectVolume(name: String) async throws -> VolumeRecord {
        let result = try await run(["volume", "inspect", name])
        if result.exitCode != 0 {
            throw ContainerCLIError.commandFailed(result.combinedOutput)
        }
        return try ContainerJSONParser.parseVolumeInspect(result.stdout)
    }

    func createVolume(name: String) async throws {
        let result = try await run(["volume", "create", name])
        if result.exitCode != 0 {
            throw ContainerCLIError.commandFailed(result.combinedOutput)
        }
    }

    func deleteVolume(name: String) async throws {
        let result = try await run(["volume", "rm", name])
        if result.exitCode != 0 {
            throw ContainerCLIError.commandFailed(result.combinedOutput)
        }
    }

    func pruneVolumes() async throws {
        let result = try await run(["volume", "prune"])
        if result.exitCode != 0 {
            throw ContainerCLIError.commandFailed(result.combinedOutput)
        }
    }

    func listNetworks() async throws -> [NetworkRecord] {
        let result = try await run(["network", "ls", "--format", "json"])
        if result.exitCode != 0 {
            throw ContainerCLIError.commandFailed(result.combinedOutput)
        }
        return try ContainerJSONParser.parseNetworkList(result.stdout)
    }

    func inspectNetwork(name: String) async throws -> NetworkRecord {
        let result = try await run(["network", "inspect", name])
        if result.exitCode != 0 {
            throw ContainerCLIError.commandFailed(result.combinedOutput)
        }
        return try ContainerJSONParser.parseNetworkInspect(result.stdout)
    }

    func createNetwork(name: String, subnet: String? = nil, internalOnly: Bool = false) async throws {
        var args = ["network", "create"]
        if internalOnly {
            args.append("--internal")
        }
        if let subnet, !subnet.isEmpty {
            args += ["--subnet", subnet]
        }
        args.append(name)

        let result = try await run(args)
        if result.exitCode != 0 {
            throw ContainerCLIError.commandFailed(result.combinedOutput)
        }
    }

    func deleteNetwork(name: String) async throws {
        let result = try await run(["network", "rm", name])
        if result.exitCode != 0 {
            throw ContainerCLIError.commandFailed(result.combinedOutput)
        }
    }

    func pruneNetworks() async throws {
        let result = try await run(["network", "prune"])
        if result.exitCode != 0 {
            throw ContainerCLIError.commandFailed(result.combinedOutput)
        }
    }

    func listMachines() async throws -> [MachineRecord] {
        let result = try await run(["machine", "ls", "--format", "json"])
        return try ContainerJSONParser.parseMachineList(result.stdout)
    }

    func inspectMachine(id: String) async throws -> MachineRecord {
        let result = try await run(["machine", "inspect", id])
        return try ContainerJSONParser.parseMachineInspect(result.stdout)
    }

    func createMachine(
        image: String,
        name: String,
        cpus: String? = nil,
        memory: String? = nil,
        homeMount: String? = nil,
        setDefault: Bool = false
    ) async throws {
        var args = ["machine", "create", "--name", name]
        if let cpus, !cpus.isEmpty {
            args += ["--cpus", cpus]
        }
        if let memory, !memory.isEmpty {
            args += ["--memory", memory]
        }
        if let homeMount, !homeMount.isEmpty {
            args += ["--home-mount", homeMount]
        }
        if setDefault {
            args.append("--set-default")
        }
        args.append(image)

        let result = try await run(args)
        if result.exitCode != 0 {
            throw ContainerCLIError.commandFailed(result.stderr.isEmpty ? result.stdout : result.stderr)
        }
    }

    func stopMachine(name: String) async throws {
        let result = try await run(["machine", "stop", name])
        if result.exitCode != 0 {
            throw ContainerCLIError.commandFailed(result.stderr.isEmpty ? result.stdout : result.stderr)
        }
    }

    func deleteMachine(name: String) async throws {
        let result = try await run(["machine", "rm", name])
        if result.exitCode != 0 {
            throw ContainerCLIError.commandFailed(result.stderr.isEmpty ? result.stdout : result.stderr)
        }
    }

    func setDefaultMachine(name: String) async throws {
        let result = try await run(["machine", "set-default", name])
        if result.exitCode != 0 {
            throw ContainerCLIError.commandFailed(result.stderr.isEmpty ? result.stdout : result.stderr)
        }
    }

    @discardableResult
    func run(_ arguments: [String]) async throws -> ContainerCommandResult {
        try await runStreaming(arguments, onOutput: nil)
    }

    private func runStreaming(
        _ arguments: [String],
        onOutput: (@Sendable (String) -> Void)?
    ) async throws -> ContainerCommandResult {
        guard let binary = resolveBinaryPath() else {
            throw ContainerCLIError.notInstalled
        }

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: binary)
                    process.arguments = arguments

                    let stdoutPipe = Pipe()
                    let stderrPipe = Pipe()
                    process.standardOutput = stdoutPipe
                    process.standardError = stderrPipe

                    var stdoutChunks: [Data] = []
                    var stderrChunks: [Data] = []
                    let dataLock = NSLock()

                    func appendOutput(_ data: Data, isStderr: Bool) {
                        guard !data.isEmpty else { return }
                        dataLock.lock()
                        if isStderr {
                            stderrChunks.append(data)
                        } else {
                            stdoutChunks.append(data)
                        }
                        dataLock.unlock()

                        if let onOutput {
                            let text = String(decoding: data, as: UTF8.self)
                            if !text.isEmpty {
                                onOutput(text)
                            }
                        }
                    }

                    stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
                        appendOutput(handle.availableData, isStderr: false)
                    }
                    stderrPipe.fileHandleForReading.readabilityHandler = { handle in
                        appendOutput(handle.availableData, isStderr: true)
                    }

                    try process.run()
                    process.waitUntilExit()

                    stdoutPipe.fileHandleForReading.readabilityHandler = nil
                    stderrPipe.fileHandleForReading.readabilityHandler = nil

                    appendOutput(stdoutPipe.fileHandleForReading.readDataToEndOfFile(), isStderr: false)
                    appendOutput(stderrPipe.fileHandleForReading.readDataToEndOfFile(), isStderr: true)

                    dataLock.lock()
                    let stdout = String(decoding: stdoutChunks.reduce(into: Data()) { $0.append($1) }, as: UTF8.self)
                    let stderr = String(decoding: stderrChunks.reduce(into: Data()) { $0.append($1) }, as: UTF8.self)
                    dataLock.unlock()

                    continuation.resume(returning: ContainerCommandResult(
                        stdout: stdout,
                        stderr: stderr,
                        exitCode: process.terminationStatus
                    ))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func runShell(_ script: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", script]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            return String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        } catch {
            return nil
        }
    }

    private func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}

enum TerminalLauncher {
    static func openExec(containerID: String) throws {
        guard let binary = resolveBinaryPath() else {
            throw ContainerCLIError.notInstalled
        }
        let command = CLICommands.containerExec(binary: binary, id: containerID)
        try openTerminal(with: command)
    }

    static func openMachineShell(machineName: String) throws {
        guard let binary = resolveBinaryPath() else {
            throw ContainerCLIError.notInstalled
        }
        let command = CLICommands.machineShell(binary: binary, name: machineName)
        try openTerminal(with: command)
    }

    static func openPrefilledCommand(_ command: String) throws {
        guard let binary = resolveBinaryPath() else {
            throw ContainerCLIError.notInstalled
        }
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        let subcommand: String
        if trimmed.hasPrefix("container ") {
            subcommand = String(trimmed.dropFirst("container ".count))
        } else {
            subcommand = trimmed
        }
        let script = CLICommands.prefilledCommand(binary: binary, subcommand: subcommand)
        try openTerminal(with: script)
    }

    private static func resolveBinaryPath() -> String? {
        let searchPaths = [
            "/usr/local/bin",
            "/opt/homebrew/bin",
            "/usr/bin",
        ]

        for directory in searchPaths {
            let candidate = (directory as NSString).appendingPathComponent("container")
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", "command -v container"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let path = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return path.isEmpty ? nil : path
        } catch {
            return nil
        }
    }

    private static func openTerminal(with command: String) throws {
        let filename = "apple-container-\(UUID().uuidString).command"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        let script = "#!/bin/zsh\n\(command)\n"
        try script.write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)

        let terminal = AppSettings.preferredTerminal
        guard TerminalApplication.isInstalled(terminal) else {
            throw ContainerCLIError.commandFailed("\(terminal.displayName) is not installed.")
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", terminal.openApplicationName, url.path]

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            throw ContainerCLIError.commandFailed("Unable to open \(terminal.displayName).")
        }

        guard process.terminationStatus == 0 else {
            throw ContainerCLIError.commandFailed("Unable to open \(terminal.displayName).")
        }

        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 10) {
            try? FileManager.default.removeItem(at: url)
        }
    }
}
