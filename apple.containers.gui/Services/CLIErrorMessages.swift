import Foundation

struct CLIErrorPresentation: Equatable {
    let message: String
    let terminalCommand: String?
}

enum CLIErrorMessages {
    static let kernelSetupCommand = CLICommands.kernelSetup
    static let systemStartCommand = CLICommands.systemStart

    static func present(_ raw: String) -> CLIErrorPresentation {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return CLIErrorPresentation(message: "An unknown error occurred.", terminalCommand: nil)
        }

        if isKernelConfigurationError(trimmed) {
            return CLIErrorPresentation(
                message: """
                The container kernel is not configured for this Mac.

                Run this command in Terminal and press Enter:
                \(kernelSetupCommand)
                """,
                terminalCommand: kernelSetupCommand
            )
        }

        if trimmed.hasPrefix("JSON decode failed:") {
            return CLIErrorPresentation(
                message: """
                Could not read the response from the container CLI. The command output format may have changed.

                Try refreshing the list. If the problem persists, run the same command in Terminal and report the output.
                """,
                terminalCommand: nil
            )
        }

        if trimmed.localizedCaseInsensitiveContains("connection invalid")
            || trimmed.localizedCaseInsensitiveContains("container system service") {
            return CLIErrorPresentation(
                message: """
                The container system service is not running.

                Run this command in Terminal and press Enter:
                \(systemStartCommand)
                """,
                terminalCommand: systemStartCommand
            )
        }

        return CLIErrorPresentation(message: trimmed, terminalCommand: nil)
    }

    static func friendly(_ raw: String) -> String {
        present(raw).message
    }

    private static func isKernelConfigurationError(_ text: String) -> Bool {
        text.localizedCaseInsensitiveContains("default kernel not configured")
            || text.localizedCaseInsensitiveContains("kernel not configured")
            || text.localizedCaseInsensitiveContains("container system kernel set")
    }
}
