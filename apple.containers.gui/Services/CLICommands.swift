import Foundation

enum CLICommands {
    static let binaryName = "container"
    static let kernelSetup = "container system kernel set --recommended"
    static let systemStart = "container system start"

    static let listContainers = "container list"
    static let listAllContainers = "container ls --all"
    static let listMachines = "container machine ls"
    static let machineAliasHint = "container m ls"

    static func machineShellCommand(name: String) -> String {
        "container machine run -n \(name)"
    }

    static func containerExecCommand(id: String) -> String {
        "container exec -it \(id) sh"
    }

    static func machineShell(binary: String, name: String) -> String {
        "\(binary) machine run -n \(name)"
    }

    static func containerExec(binary: String, id: String) -> String {
        "\(binary) exec -it \(id) sh"
    }

    static func prefilledCommand(binary: String, subcommand: String) -> String {
        "\(binary) \(subcommand)"
    }

    static let macOSMachineWarning = """
    Do not run 'machine' or 'machines' by itself in Terminal.
    macOS ships /usr/bin/machine (CPU architecture tool).
    Use 'container machine ls' to list container machines.
    """
}
