import Foundation
import Observation
import CoreGraphics
import AppKit
import UniformTypeIdentifiers

enum ResourceTransition: String, Sendable {
    case stopping
    case starting
    case deleting
    case creating
}

struct AppToast: Identifiable, Sendable {
    let id = UUID()
    let message: String
}

@Observable
@MainActor
final class AppViewModel {
    var isCLIInstalled = false
    var cliVersion = ""
    var isLoading = false
    var errorMessage: String?
    var errorTerminalCommand: String?
    var showInstallSheet = false

    var selectedSection: SidebarSection = .containers
    var containers: [ContainerRecord] = []
    var machines: [MachineRecord] = []
    var selectedContainerID: String?
    var selectedMachineID: String?

    var selectedContainer: ContainerRecord? {
        containers.first { $0.id == selectedContainerID }
    }

    var selectedMachine: MachineRecord? {
        machines.first { $0.displayID == selectedMachineID }
    }

    var showCreateContainer = false
    var showEditContainer = false
    var showCreateMachine = false
    var showContainerRunProgress = false
    var isContainerRunInProgress = false
    var containerRunProgressOutput = ""
    var containerRunProgressTitle = ""
    var toast: AppToast?
    var createContainerForm = CreateContainerForm.defaults
    var editContainerForm = CreateContainerForm.defaults
    var editContainerOriginalID: String?
    var editContainerOriginalCommand: [String] = []
    var createMachineForm = CreateMachineForm.defaults
    var createContainerError: String?
    var createContainerTerminalCommand: String?
    var editContainerError: String?
    var editContainerTerminalCommand: String?
    var createMachineError: String?
    var createMachineTerminalCommand: String?

    var showImportComposePicker = false
    var composeImportSourceName: String?
    private var pendingComposeImport: ContainerComposeDocument?

    var importComposeServiceNames: [String]? {
        guard let pendingComposeImport else { return nil }
        return pendingComposeImport.services.keys.sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
    }

    var preferredTerminal: TerminalApplication = AppSettings.preferredTerminal {
        didSet { AppSettings.preferredTerminal = preferredTerminal }
    }

    var defaultDataDirectory: String = AppSettings.defaultDataDirectory {
        didSet { AppSettings.defaultDataDirectory = defaultDataDirectory }
    }

    var availableTerminals: [TerminalApplication] {
        TerminalApplication.available
    }

    var workspaceTabs: [WorkspaceTab] = []
    var selectedWorkspaceTabID: UUID?
    var isWorkspacePanelOpen = false
    var workspacePanelHeight: CGFloat = AppSettings.workspacePanelHeight {
        didSet {
            AppSettings.workspacePanelHeight = workspacePanelHeight
        }
    }

    var selectedWorkspaceTab: WorkspaceTab? {
        workspaceTabs.first { $0.id == selectedWorkspaceTabID }
    }

    var containerCLIPath = "/usr/local/bin/container"

    private(set) var containerTransitions: [String: ResourceTransition] = [:]
    private(set) var machineTransitions: [String: ResourceTransition] = [:]

    private var refreshTask: Task<Void, Never>?
    private var pollTask: Task<Void, Never>?
    private let cli = ContainerCLI.shared

    func bootstrap() async {
        isCLIInstalled = await cli.isInstalled()
        guard isCLIInstalled else {
            showInstallSheet = true
            return
        }

        do {
            cliVersion = try await cli.version()
            if let path = await cli.resolveBinaryPath() {
                containerCLIPath = path
            }
            try await cli.ensureSystemRunning()
            await refreshAll()
            startAutoRefresh()
        } catch {
            applyGlobalError(from: error.localizedDescription)
        }
    }

    func recheckInstallation() async {
        isCLIInstalled = await cli.isInstalled()
        if isCLIInstalled {
            showInstallSheet = false
            await bootstrap()
        }
    }

    func refreshAll() async {
        await refreshLists(silent: false)
    }

    func refreshLists(silent: Bool = true) async {
        if !silent { isLoading = true }
        defer { if !silent { isLoading = false } }

        do {
            async let containerList = cli.listContainers(all: true)
            async let machineList = cli.listMachines()
            containers = try await containerList
            machines = try await machineList

            if selectedContainerID == nil {
                selectedContainerID = containers.first?.id
            } else if !containers.contains(where: { $0.id == selectedContainerID }) {
                selectedContainerID = containers.first?.id
            }

            if selectedMachineID == nil {
                selectedMachineID = machines.first?.displayID
            } else if !machines.contains(where: { $0.displayID == selectedMachineID }) {
                selectedMachineID = machines.first?.displayID
            }

            reconcileTransitions()
            if silent { clearGlobalError() }
            else { clearGlobalError() }
        } catch {
            if !silent {
                applyGlobalError(from: error.localizedDescription)
            }
        }
    }

    func containerDisplayStatus(for id: String) -> (label: String, isRunning: Bool, isTransitioning: Bool) {
        if let transition = containerTransitions[id] {
            return (transitionLabel(transition), false, true)
        }
        guard let container = containers.first(where: { $0.id == id }) else {
            return ("unknown", false, false)
        }
        let status = container.status?.lowercased() ?? "unknown"
        return (status, container.isRunning, false)
    }

    func machineDisplayStatus(for id: String) -> (label: String, isRunning: Bool, isTransitioning: Bool) {
        if let transition = machineTransitions[id] {
            return (transitionLabel(transition), false, true)
        }
        guard let machine = machines.first(where: { $0.displayID == id }) else {
            return ("unknown", false, false)
        }
        let status = machine.status?.lowercased() ?? "unknown"
        return (status, machine.isRunning, false)
    }

    private func transitionLabel(_ transition: ResourceTransition) -> String {
        switch transition {
        case .stopping: "stopping..."
        case .starting: "starting..."
        case .deleting: "deleting..."
        case .creating: "creating..."
        }
    }

    private func setContainerTransition(_ id: String, _ transition: ResourceTransition) {
        containerTransitions[id] = transition
        scheduleAcceleratedPolling()
    }

    private func setMachineTransition(_ id: String, _ transition: ResourceTransition) {
        machineTransitions[id] = transition
        scheduleAcceleratedPolling()
    }

    private func clearContainerTransition(_ id: String) {
        containerTransitions.removeValue(forKey: id)
    }

    private func clearMachineTransition(_ id: String) {
        machineTransitions.removeValue(forKey: id)
    }

    private func reconcileTransitions() {
        for (id, _) in containerTransitions {
            guard let container = containers.first(where: { $0.id == id }) else {
                containerTransitions.removeValue(forKey: id)
                continue
            }
            guard let transition = containerTransitions[id] else { continue }
            switch transition {
            case .stopping where !container.isRunning:
                containerTransitions.removeValue(forKey: id)
            case .starting where container.isRunning:
                containerTransitions.removeValue(forKey: id)
            case .deleting:
                containerTransitions.removeValue(forKey: id)
            case .creating where container.status != nil:
                containerTransitions.removeValue(forKey: id)
            default:
                break
            }
        }

        for (id, _) in machineTransitions {
            guard let machine = machines.first(where: { $0.displayID == id }) else {
                machineTransitions.removeValue(forKey: id)
                continue
            }
            guard let transition = machineTransitions[id] else { continue }
            switch transition {
            case .stopping where !machine.isRunning:
                machineTransitions.removeValue(forKey: id)
            case .starting where machine.isRunning:
                machineTransitions.removeValue(forKey: id)
            case .deleting:
                machineTransitions.removeValue(forKey: id)
            case .creating where machine.status != nil:
                machineTransitions.removeValue(forKey: id)
            default:
                break
            }
        }
    }

    private func scheduleAcceleratedPolling() {
        pollTask?.cancel()
        pollTask = Task {
            for _ in 0..<30 {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                await refreshLists(silent: true)
                if containerTransitions.isEmpty && machineTransitions.isEmpty {
                    return
                }
            }
            containerTransitions.removeAll()
            machineTransitions.removeAll()
        }
    }

    func prepareCreateContainerSheet() {
        createContainerForm.reset()
        createContainerError = nil
        createContainerTerminalCommand = nil
        composeImportSourceName = nil
        showCreateContainer = true
    }

    func exportSelectedContainerToCompose() async {
        guard let id = selectedContainerID else { return }

        do {
            let record = try await cli.inspectContainer(id: id)
            let yaml = ContainerComposeYAML.encode(.from(record: record))

            let panel = NSSavePanel()
            panel.title = "Export Container"
            panel.prompt = "Export"
            panel.canCreateDirectories = true
            panel.nameFieldStringValue = "\(record.containerID).compose.yaml"
            if let yamlType = UTType(filenameExtension: "yaml") {
                panel.allowedContentTypes = [yamlType]
            }

            guard panel.runModal() == .OK, let url = panel.url else { return }
            try yaml.write(to: url, atomically: true, encoding: .utf8)
            showToast("Exported compose file to \(url.path)")
        } catch {
            applyGlobalError(from: error.localizedDescription)
        }
    }

    func importContainerCompose() {
        let panel = NSOpenPanel()
        panel.title = "Import Compose"
        panel.prompt = "Import"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        if let yamlType = UTType(filenameExtension: "yaml") {
            panel.allowedContentTypes = [yamlType, UTType(filenameExtension: "yml")].compactMap { $0 }
        }

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let text = try String(contentsOf: url, encoding: .utf8)
            let document = try ContainerComposeYAML.decode(text)
            let serviceNames = document.services.keys.sorted {
                $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
            }
            guard !serviceNames.isEmpty else {
                throw ContainerComposeError.noServices
            }

            pendingComposeImport = document
            composeImportSourceName = url.lastPathComponent

            if serviceNames.count == 1, let only = serviceNames.first {
                applyComposeImport(serviceName: only)
            } else {
                showImportComposePicker = true
            }
        } catch {
            applyGlobalError(from: error.localizedDescription)
        }
    }

    func applyComposeImport(serviceName: String) {
        guard let document = pendingComposeImport,
              let service = document.services[serviceName] else {
            applyGlobalError(from: "Selected compose service was not found.")
            return
        }

        createContainerForm = service.toCreateContainerForm(serviceName: serviceName)
        createContainerError = nil
        createContainerTerminalCommand = nil
        pendingComposeImport = nil
        showImportComposePicker = false
        showCreateContainer = true
    }

    func cancelComposeImport() {
        pendingComposeImport = nil
        composeImportSourceName = nil
        showImportComposePicker = false
    }

    func prepareEditContainerSheet() async {
        guard let id = selectedContainerID else { return }

        editContainerError = nil
        editContainerTerminalCommand = nil
        isLoading = true
        defer { isLoading = false }

        do {
            let record = try await cli.inspectContainer(id: id)
            editContainerOriginalID = id
            editContainerOriginalCommand = originalCommand(from: record)
            editContainerForm = CreateContainerForm.from(record: record)
            showEditContainer = true
        } catch {
            applyGlobalError(from: error.localizedDescription)
        }
    }

    func editContainer() async -> Bool {
        editContainerError = nil
        editContainerTerminalCommand = nil

        guard let originalID = editContainerOriginalID else {
            editContainerError = "No container selected for editing."
            return false
        }

        if let validationError = editContainerForm.validate() {
            editContainerError = validationError
            return false
        }

        let form = editContainerForm
        let containerName = form.name.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? originalID
        isLoading = true
        defer { isLoading = false }

        do {
            let commandParts = form.commandParts()
            let effectiveCommand = commandParts.isEmpty ? editContainerOriginalCommand : commandParts
            try form.ensureHostPathsExist()

            if containers.first(where: { $0.id == originalID })?.isRunning == true {
                try await cli.stopContainer(id: originalID)
            }
            try await cli.deleteContainer(id: originalID, force: true)

            let newID = try await cli.runContainer(
                image: form.image.trimmingCharacters(in: .whitespacesAndNewlines),
                name: containerName,
                command: effectiveCommand,
                volumes: form.cliVolumes(),
                ports: form.cliPorts(),
                env: form.cliEnv(),
                workdir: form.workdir.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                cpus: form.cpus.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                memory: form.memory.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            )

            editContainerForm.reset()
            editContainerOriginalID = nil
            editContainerOriginalCommand = []
            showEditContainer = false
            await refreshLists(silent: false)
            selectedSection = .containers
            selectedContainerID = containerName.nilIfEmpty ?? newID
            return true
        } catch {
            applyEditContainerError(from: error.localizedDescription)
            return false
        }
    }

    func prepareCreateMachineSheet() {
        createMachineForm.reset()
        createMachineError = nil
        createMachineTerminalCommand = nil
        showCreateMachine = true
    }

    func createContainer() async {
        createContainerError = nil
        createContainerTerminalCommand = nil

        if let validationError = createContainerForm.validate() {
            createContainerError = validationError
            return
        }

        let form = createContainerForm
        let image = form.image.trimmingCharacters(in: .whitespacesAndNewlines)
        let containerName = form.name.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty

        showCreateContainer = false
        showContainerRunProgress = true
        isContainerRunInProgress = true
        containerRunProgressOutput = ""
        containerRunProgressTitle = containerName ?? image

        do {
            let commandParts = form.commandParts()
            try form.ensureHostPathsExist()

            let id = try await cli.runContainer(
                image: image,
                name: containerName,
                command: commandParts,
                volumes: form.cliVolumes(),
                ports: form.cliPorts(),
                env: form.cliEnv(),
                workdir: form.workdir.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                cpus: form.cpus.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                memory: form.memory.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                onOutput: { [weak self] chunk in
                    Task { @MainActor in
                        self?.containerRunProgressOutput += chunk
                    }
                }
            )

            isContainerRunInProgress = false
            showContainerRunProgress = false
            createContainerForm.reset()
            composeImportSourceName = nil

            let selectedID = containerName ?? id
            if !selectedID.isEmpty {
                setContainerTransition(selectedID, .creating)
            }

            await refreshLists(silent: false)
            selectedSection = .containers
            selectedContainerID = selectedID.isEmpty ? id : selectedID
            scheduleAcceleratedPolling()
        } catch {
            isContainerRunInProgress = false
            showContainerRunProgress = false
            showCreateContainer = true

            let presentation = CLIErrorMessages.present(error.localizedDescription)
            showToast(presentation.message)
            createContainerError = presentation.message
            createContainerTerminalCommand = presentation.terminalCommand
        }
    }

    func showToast(_ message: String) {
        toast = AppToast(message: message)
    }

    func dismissToast() {
        toast = nil
    }

    func copyToastToClipboard() {
        guard let message = toast?.message else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(message, forType: .string)
    }

    func deleteSelectedContainer() async {
        guard let id = selectedContainerID else { return }
        setContainerTransition(id, .deleting)

        do {
            try await cli.deleteContainer(id: id)
            workspaceTabs.removeAll { $0.containerID == id }
            if workspaceTabs.isEmpty {
                isWorkspacePanelOpen = false
                selectedWorkspaceTabID = nil
            }
            selectedContainerID = nil
            clearContainerTransition(id)
            await refreshLists(silent: false)
        } catch {
            clearContainerTransition(id)
            applyGlobalError(from: error.localizedDescription)
        }
    }

    func stopSelectedContainer() async {
        guard let id = selectedContainerID else { return }
        setContainerTransition(id, .stopping)

        do {
            try await cli.stopContainer(id: id)
            await refreshLists(silent: true)
            scheduleAcceleratedPolling()
        } catch {
            clearContainerTransition(id)
            applyGlobalError(from: error.localizedDescription)
        }
    }

    func startSelectedContainer() async {
        guard let id = selectedContainerID else { return }
        setContainerTransition(id, .starting)

        do {
            try await cli.startContainer(id: id)
            await refreshLists(silent: true)
            scheduleAcceleratedPolling()
        } catch {
            clearContainerTransition(id)
            applyGlobalError(from: error.localizedDescription)
        }
    }

    func execSelectedContainer() {
        guard let id = selectedContainerID else { return }
        openWorkspaceExec(for: id)
    }

    func workspaceTabTitle(containerID: String, kind: WorkspaceTabKind, index: Int = 0) -> String {
        let name = containerDisplayName(for: containerID)
        switch kind {
        case .logs:
            return "\(name) · Logs"
        case .exec:
            if index == 0 { return "\(name) · Exec" }
            return "\(name) · Exec \(index + 1)"
        }
    }

    private func containerDisplayName(for containerID: String) -> String {
        if let container = containers.first(where: { $0.id == containerID }) {
            return container.displayName
        }
        if containerID.count > 14 {
            return String(containerID.prefix(12)) + "…"
        }
        return containerID
    }

    func openWorkspaceLogs(for containerID: String) {
        if let existing = workspaceTabs.first(where: { $0.containerID == containerID && $0.kind == .logs }) {
            selectedWorkspaceTabID = existing.id
        } else {
            let tab = WorkspaceTab(
                containerID: containerID,
                kind: .logs,
                title: workspaceTabTitle(containerID: containerID, kind: .logs)
            )
            workspaceTabs.append(tab)
            selectedWorkspaceTabID = tab.id
        }
        isWorkspacePanelOpen = true
    }

    func openWorkspaceExec(for containerID: String) {
        let execCount = workspaceTabs.filter { $0.containerID == containerID && $0.kind == .exec }.count
        let tab = WorkspaceTab(
            containerID: containerID,
            kind: .exec,
            title: workspaceTabTitle(containerID: containerID, kind: .exec, index: execCount)
        )
        workspaceTabs.append(tab)
        selectedWorkspaceTabID = tab.id
        isWorkspacePanelOpen = true
    }

    func selectWorkspaceTab(_ id: UUID) {
        selectedWorkspaceTabID = id
        isWorkspacePanelOpen = true
    }

    func closeWorkspaceTab(_ id: UUID) {
        workspaceTabs.removeAll { $0.id == id }
        if selectedWorkspaceTabID == id {
            selectedWorkspaceTabID = workspaceTabs.last?.id
            if workspaceTabs.isEmpty {
                isWorkspacePanelOpen = false
            }
        }
    }

    func closeWorkspacePanel() {
        isWorkspacePanelOpen = false
    }

    func openExternalExec(for containerID: String) {
        do {
            try TerminalLauncher.openExec(containerID: containerID)
        } catch {
            applyGlobalError(from: error.localizedDescription)
        }
    }

    private func originalCommand(from record: ContainerRecord) -> [String] {
        guard let process = record.configuration?.process else { return [] }
        let executable = process.executable?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let args = process.args ?? []
        if executable.isEmpty {
            return args
        }
        return [executable] + args
    }

    func createMachine() async -> Bool {
        createMachineError = nil
        createMachineTerminalCommand = nil

        if let validationError = createMachineForm.validate() {
            createMachineError = validationError
            return false
        }

        let form = createMachineForm
        let machineName = form.name.trimmingCharacters(in: .whitespacesAndNewlines)
        setMachineTransition(machineName, .creating)
        isLoading = true
        defer { isLoading = false }

        do {
            try await cli.createMachine(
                image: form.image.trimmingCharacters(in: .whitespacesAndNewlines),
                name: machineName,
                cpus: form.cpus.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                memory: form.memory.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                homeMount: form.homeMount.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                setDefault: form.setDefault
            )
            createMachineForm.reset()
            showCreateMachine = false
            await refreshLists(silent: false)
            selectedSection = .machines
            selectedMachineID = machineName
            clearMachineTransition(machineName)
            scheduleAcceleratedPolling()
            return true
        } catch {
            clearMachineTransition(machineName)
            applyCreateMachineError(from: error.localizedDescription)
            return false
        }
    }

    func deleteSelectedMachine() async {
        guard let name = selectedMachineID else { return }
        setMachineTransition(name, .deleting)

        do {
            try await cli.deleteMachine(name: name)
            selectedMachineID = nil
            clearMachineTransition(name)
            await refreshLists(silent: false)
        } catch {
            clearMachineTransition(name)
            applyGlobalError(from: error.localizedDescription)
        }
    }

    func stopSelectedMachine() async {
        guard let name = selectedMachineID else { return }
        setMachineTransition(name, .stopping)

        do {
            try await cli.stopMachine(name: name)
            await refreshLists(silent: true)
            scheduleAcceleratedPolling()
        } catch {
            clearMachineTransition(name)
            applyGlobalError(from: error.localizedDescription)
        }
    }

    func setDefaultSelectedMachine() async {
        guard let name = selectedMachineID else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            try await cli.setDefaultMachine(name: name)
            await refreshAll()
        } catch {
            applyGlobalError(from: error.localizedDescription)
        }
    }

    func openSelectedMachineShell() {
        guard let name = selectedMachineID else { return }
        do {
            try TerminalLauncher.openMachineShell(machineName: name)
        } catch {
            applyGlobalError(from: error.localizedDescription)
        }
    }

    func fetchLogs(for containerID: String) async throws -> String {
        try await cli.containerLogs(id: containerID)
    }

    func fetchInspect(for containerID: String) async throws -> ContainerRecord {
        try await cli.inspectContainer(id: containerID)
    }

    func fetchInspectRawJSON(for containerID: String) async throws -> String {
        try await cli.inspectContainerRawJSON(id: containerID)
    }

    func fetchMachineInspect(for machineID: String) async throws -> MachineRecord {
        try await cli.inspectMachine(id: machineID)
    }

    private func startAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                await refreshLists(silent: true)
            }
        }
    }

    private func splitLines(_ text: String) -> [String] {
        text
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private func applyGlobalError(from raw: String) {
        let presentation = CLIErrorMessages.present(raw)
        errorMessage = presentation.message
        errorTerminalCommand = presentation.terminalCommand
    }

    private func clearGlobalError() {
        errorMessage = nil
        errorTerminalCommand = nil
    }

    private func applyCreateContainerError(from raw: String) {
        let presentation = CLIErrorMessages.present(raw)
        createContainerError = presentation.message
        createContainerTerminalCommand = presentation.terminalCommand
    }

    private func applyEditContainerError(from raw: String) {
        let presentation = CLIErrorMessages.present(raw)
        editContainerError = presentation.message
        editContainerTerminalCommand = presentation.terminalCommand
    }

    private func applyCreateMachineError(from raw: String) {
        let presentation = CLIErrorMessages.present(raw)
        createMachineError = presentation.message
        createMachineTerminalCommand = presentation.terminalCommand
    }

    func openErrorTerminalCommand() {
        guard let command = errorTerminalCommand else { return }
        try? TerminalLauncher.openPrefilledCommand(command)
    }

    func reportError(from raw: String) {
        applyGlobalError(from: raw)
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
