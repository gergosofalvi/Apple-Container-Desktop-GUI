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
    var volumes: [VolumeRecord] = []
    var networks: [NetworkRecord] = []
    var containerGroups: [ContainerGroup] = []
    var machines: [MachineRecord] = []
    var selectedContainerID: String?
    var selectedVolumeName: String?
    var selectedNetworkName: String?
    var selectedMachineID: String?

    var selectedContainer: ContainerRecord? {
        containers.first { $0.id == selectedContainerID }
    }

    var selectedMachine: MachineRecord? {
        machines.first { $0.displayID == selectedMachineID }
    }

    var selectedVolume: VolumeRecord? {
        volumes.first { $0.name == selectedVolumeName }
    }

    var selectedNetwork: NetworkRecord? {
        networks.first { $0.name == selectedNetworkName }
    }

    var showCreateNetwork = false
    var showCreateVolume = false
    var showManageGroup = false
    var createNetworkForm = CreateNetworkForm()
    var createVolumeForm = CreateVolumeForm()
    var createNetworkError: String?
    var createVolumeError: String?
    var manageGroupForm = ManageGroupForm()
    var manageGroupError: String?

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
            containerGroups = ContainerGroupStore.load()
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
            async let volumeList = cli.listVolumes()
            async let networkList = cli.listNetworks()
            async let machineList = cli.listMachines()
            containers = try await containerList
            volumes = try await volumeList
            networks = try await networkList
            machines = try await machineList
            pruneMissingGroupMembers()

            if selectedContainerID == nil {
                selectedContainerID = containers.first?.id
            } else if !containers.contains(where: { $0.id == selectedContainerID }) {
                selectedContainerID = containers.first?.id
            }

            if selectedVolumeName == nil {
                selectedVolumeName = volumes.first?.name
            } else if !volumes.contains(where: { $0.name == selectedVolumeName }) {
                selectedVolumeName = volumes.first?.name
            }

            if selectedNetworkName == nil {
                selectedNetworkName = networks.first?.name
            } else if !networks.contains(where: { $0.name == selectedNetworkName }) {
                selectedNetworkName = networks.first?.name
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

    func containerGroup(for containerID: String) -> ContainerGroup? {
        containerGroups.first { $0.memberContainerIDs.contains(containerID) }
    }

    func networkPeers(for containerID: String) -> [NetworkPeerEndpoint] {
        guard let group = containerGroup(for: containerID) else { return [] }
        return group.memberContainerIDs
            .filter { $0 != containerID }
            .compactMap { memberID in
                guard let container = containers.first(where: { $0.id == memberID }) else { return nil }
                return NetworkPeerEndpoint(
                    containerID: container.id,
                    networkName: container.networkHostName,
                    ipv4Address: container.ipv4Address
                )
            }
            .sorted { $0.networkName.localizedCaseInsensitiveCompare($1.networkName) == .orderedAscending }
    }

    func prepareCreateContainerSheet() {
        createContainerForm.reset()
        createContainerError = nil
        createContainerTerminalCommand = nil
        composeImportSourceName = nil
        showCreateContainer = true
        Task { await ensureResourceListsLoaded() }
    }

    func openContainerFromResource(_ containerID: String) {
        selectedSection = .containers
        selectedContainerID = containerID
    }

    func prepareCreateGroupSheet() {
        manageGroupForm = ManageGroupForm()
        manageGroupError = nil
        showManageGroup = true
        Task { await ensureResourceListsLoaded() }
    }

    func prepareManageGroupSheet(group: ContainerGroup) {
        manageGroupForm = ManageGroupForm(
            groupID: group.id,
            name: group.name,
            networkName: group.networkName,
            selectedContainerIDs: Set(group.memberContainerIDs)
        )
        manageGroupError = nil
        showManageGroup = true
        Task { await ensureResourceListsLoaded() }
    }

    func ensureResourceListsLoaded() async {
        do {
            if networks.isEmpty {
                networks = try await cli.listNetworks()
            }
            if volumes.isEmpty {
                volumes = try await cli.listVolumes()
            }
        } catch {
            reportError(from: error.localizedDescription)
        }
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

    func importComposeStack(named stackName: String, networkName: String = "default") async {
        guard let document = pendingComposeImport else {
            applyGlobalError(from: "No compose file is loaded.")
            return
        }

        let trimmedName = stackName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            applyGlobalError(from: "Stack name is required.")
            return
        }

        let serviceNames = document.services.keys.sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
        guard !serviceNames.isEmpty else {
            applyGlobalError(from: "Compose file does not contain any services.")
            return
        }

        let sourceFile = composeImportSourceName
        let stackNetwork = networkName.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "default"
        pendingComposeImport = nil
        composeImportSourceName = nil
        showImportComposePicker = false
        showCreateContainer = false
        showContainerRunProgress = true
        isContainerRunInProgress = true
        containerRunProgressOutput = "Deploying stack \"\(trimmedName)\"...\n"
        containerRunProgressTitle = trimmedName

        var memberIDs: [String] = []

        do {
            for serviceName in serviceNames {
                guard let service = document.services[serviceName] else { continue }
                var form = service.toCreateContainerForm(serviceName: serviceName)
                form.networkName = stackNetwork
                form.groupMode = .new
                form.newGroupName = trimmedName
                try form.ensureHostPathsExist()

                containerRunProgressOutput += "\n--- \(serviceName) ---\n"

                let progressSink = makeRunProgressSink()
                let containerID = try await runContainerFromForm(form, onOutput: progressSink.emit)

                let selectedID = containerID.nilIfEmpty ?? form.containerRunName() ?? serviceName
                memberIDs.append(selectedID)
                setContainerTransition(selectedID, .creating)
            }

            let group = ContainerGroup(
                name: trimmedName,
                networkName: stackNetwork,
                memberContainerIDs: memberIDs,
                sourceFile: sourceFile
            )
            containerGroups.append(group)
            persistContainerGroups()

            isContainerRunInProgress = false
            showContainerRunProgress = false
            createContainerForm.reset()

            await refreshLists(silent: false)
            selectedSection = .containers
            selectedContainerID = memberIDs.first
            showToast("Stack \"\(trimmedName)\" deployed with \(memberIDs.count) containers.")
            scheduleAcceleratedPolling()
        } catch {
            isContainerRunInProgress = false
            showContainerRunProgress = false
            applyGlobalError(from: error.localizedDescription)
        }
    }

    func containers(in group: ContainerGroup) -> [ContainerRecord] {
        let ids = Set(group.memberContainerIDs)
        return containers.filter { ids.contains($0.id) }
    }

    var ungroupedContainers: [ContainerRecord] {
        let groupedIDs = Set(containerGroups.flatMap(\.memberContainerIDs))
        return containers.filter { !groupedIDs.contains($0.id) }
    }

    func containers(usingVolume volumeName: String) -> [ContainerRecord] {
        ContainerResourceIndex.containers(usingVolume: volumeName, in: containers)
    }

    func containers(onNetwork networkName: String) -> [ContainerRecord] {
        ContainerResourceIndex.containers(onNetwork: networkName, in: containers)
    }

    func deleteContainerGroup(_ group: ContainerGroup) {
        containerGroups.removeAll { $0.id == group.id }
        persistContainerGroups()
    }

    func saveManageGroup() async -> Bool {
        manageGroupError = nil
        let isCreate = manageGroupForm.groupID == nil
        if let validationError = manageGroupForm.validate(isCreate: isCreate) {
            manageGroupError = validationError
            return false
        }

        let name = manageGroupForm.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let network = manageGroupForm.networkName.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "default"
        let selectedIDs = manageGroupForm.selectedContainerIDs

        isLoading = true
        defer { isLoading = false }

        do {
            if isCreate {
                var memberIDs: [String] = []
                for containerID in selectedIDs.sorted() {
                    removeContainerFromOtherGroups(containerID)
                    let newID = try await recreateContainerWithNetwork(containerID, network: network)
                    memberIDs.append(newID)
                }
                let group = ContainerGroup(
                    name: name,
                    networkName: network,
                    memberContainerIDs: memberIDs
                )
                containerGroups.append(group)
                persistContainerGroups()
            } else if let groupID = manageGroupForm.groupID,
                      let index = containerGroups.firstIndex(where: { $0.id == groupID }) {
                let oldGroup = containerGroups[index]
                let oldMembers = Set(oldGroup.memberContainerIDs)
                let newMembers = selectedIDs
                let added = newMembers.subtracting(oldMembers)
                let networkChanged = oldGroup.networkName != network

                var updatedMemberIDs = Array(newMembers)
                var idMapping: [String: String] = [:]

                let needsRecreate: Set<String> = networkChanged ? newMembers : added
                for containerID in needsRecreate.sorted() {
                    removeContainerFromOtherGroups(containerID, except: groupID)
                    let newID = try await recreateContainerWithNetwork(containerID, network: network)
                    idMapping[containerID] = newID
                }

                updatedMemberIDs = newMembers.map { idMapping[$0] ?? $0 }

                if updatedMemberIDs.isEmpty {
                    containerGroups.remove(at: index)
                } else {
                    containerGroups[index] = ContainerGroup(
                        id: groupID,
                        name: name,
                        networkName: network,
                        memberContainerIDs: updatedMemberIDs,
                        sourceFile: oldGroup.sourceFile,
                        createdAt: oldGroup.createdAt
                    )
                }
                persistContainerGroups()
            }

            manageGroupForm.reset()
            showManageGroup = false
            await refreshLists(silent: false)
            selectedSection = .containers
            showToast(isCreate ? "Group \"\(name)\" created." : "Group \"\(name)\" updated.")
            return true
        } catch {
            manageGroupError = error.localizedDescription
            return false
        }
    }

    private func assignContainerToGroup(containerID: String, form: CreateContainerForm) {
        switch form.groupMode {
        case .none:
            break
        case .existing:
            guard let groupID = form.selectedExistingGroupID,
                  let index = containerGroups.firstIndex(where: { $0.id == groupID }) else {
                return
            }
            removeContainerFromOtherGroups(containerID, except: groupID)
            var group = containerGroups[index]
            if !group.memberContainerIDs.contains(containerID) {
                group.memberContainerIDs.append(containerID)
                containerGroups[index] = group
                persistContainerGroups()
            }
        case .new:
            let name = form.newGroupName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return }
            let network = form.networkName.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "default"
            removeContainerFromOtherGroups(containerID)
            let group = ContainerGroup(
                name: name,
                networkName: network,
                memberContainerIDs: [containerID]
            )
            containerGroups.append(group)
            persistContainerGroups()
        }
    }

    private func removeContainerFromOtherGroups(_ containerID: String, except groupID: UUID? = nil) {
        var changed = false
        containerGroups = containerGroups.map { group in
            guard group.id != groupID else { return group }
            var updated = group
            let filtered = updated.memberContainerIDs.filter { $0 != containerID }
            if filtered.count != updated.memberContainerIDs.count {
                updated.memberContainerIDs = filtered
                changed = true
            }
            return updated
        }
        if changed {
            persistContainerGroups()
        }
    }

    private func recreateContainerWithNetwork(_ containerID: String, network: String) async throws -> String {
        let record = try await cli.inspectContainer(id: containerID)
        var form = CreateContainerForm.from(record: record, groups: containerGroups)
        form.networkName = network
        let command = originalCommand(from: record)
        let effectiveCommand = command.isEmpty ? form.commandParts() : command
        return try await recreateContainer(originalID: containerID, form: form, command: effectiveCommand)
    }

    private func recreateContainer(
        originalID: String,
        form: CreateContainerForm,
        command: [String],
        onOutput: (@Sendable (String) -> Void)? = nil
    ) async throws -> String {
        try form.ensureHostPathsExist()

        if containers.first(where: { $0.id == originalID })?.isRunning == true {
            try await cli.stopContainer(id: originalID)
        }
        try await cli.deleteContainer(id: originalID, force: true)

        let network = form.networkName.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "default"
        let runName = form.containerRunName()
        let newID = try await cli.runContainer(
            image: form.image.trimmingCharacters(in: .whitespacesAndNewlines),
            name: runName,
            command: command,
            volumes: form.cliVolumes(),
            ports: form.cliPorts(),
            env: form.cliEnv(),
            workdir: form.workdir.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            cpus: form.cpus.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            memory: form.memory.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            network: network,
            onOutput: onOutput
        )

        return newID.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? runName ?? originalID
    }

    func containerDisplayName(for container: ContainerRecord) -> String {
        container.containerID
    }

    func prepareCreateVolumeSheet() {
        createVolumeForm.reset()
        createVolumeError = nil
        showCreateVolume = true
    }

    func prepareCreateNetworkSheet() {
        createNetworkForm.reset()
        createNetworkError = nil
        showCreateNetwork = true
    }

    func createVolumeNamed(_ name: String) async -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        do {
            try await cli.createVolume(name: trimmed)
            volumes = try await cli.listVolumes()
            return true
        } catch {
            reportError(from: error.localizedDescription)
            return false
        }
    }

    func createVolume() async -> Bool {
        createVolumeError = nil
        if let validationError = createVolumeForm.validate() {
            createVolumeError = validationError
            return false
        }

        let name = createVolumeForm.name.trimmingCharacters(in: .whitespacesAndNewlines)
        isLoading = true
        defer { isLoading = false }

        do {
            try await cli.createVolume(name: name)
            createVolumeForm.reset()
            showCreateVolume = false
            await refreshLists(silent: false)
            selectedSection = .volumes
            selectedVolumeName = name
            return true
        } catch {
            createVolumeError = error.localizedDescription
            return false
        }
    }

    func createNetwork() async -> Bool {
        createNetworkError = nil
        if let validationError = createNetworkForm.validate() {
            createNetworkError = validationError
            return false
        }

        let name = createNetworkForm.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let subnet = createNetworkForm.subnet.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        isLoading = true
        defer { isLoading = false }

        do {
            try await cli.createNetwork(
                name: name,
                subnet: subnet,
                internalOnly: createNetworkForm.internalOnly
            )
            createNetworkForm.reset()
            showCreateNetwork = false
            await refreshLists(silent: false)
            selectedSection = .networks
            selectedNetworkName = name
            return true
        } catch {
            createNetworkError = error.localizedDescription
            return false
        }
    }

    func deleteSelectedVolume() async {
        guard let name = selectedVolumeName else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            try await cli.deleteVolume(name: name)
            selectedVolumeName = nil
            await refreshLists(silent: false)
        } catch {
            applyGlobalError(from: error.localizedDescription)
        }
    }

    func deleteSelectedNetwork() async {
        guard let name = selectedNetworkName else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            try await cli.deleteNetwork(name: name)
            selectedNetworkName = nil
            await refreshLists(silent: false)
        } catch {
            applyGlobalError(from: error.localizedDescription)
        }
    }

    func fetchVolumeInspect(for name: String) async throws -> VolumeRecord {
        try await cli.inspectVolume(name: name)
    }

    func fetchNetworkInspect(for name: String) async throws -> NetworkRecord {
        try await cli.inspectNetwork(name: name)
    }

    private func persistContainerGroups() {
        ContainerGroupStore.save(containerGroups)
    }

    private func pruneMissingGroupMembers() {
        let existingIDs = Set(containers.map(\.id))
        var changed = false
        containerGroups = containerGroups.map { group in
            var updated = group
            let filtered = updated.memberContainerIDs.filter { existingIDs.contains($0) }
            if filtered.count != updated.memberContainerIDs.count {
                updated.memberContainerIDs = filtered
                changed = true
            }
            return updated
        }
        if changed {
            persistContainerGroups()
        }
    }

    private func runContainerFromForm(
        _ form: CreateContainerForm,
        onOutput: (@Sendable (String) -> Void)? = nil
    ) async throws -> String {
        let image = form.image.trimmingCharacters(in: .whitespacesAndNewlines)

        return try await cli.runContainer(
            image: image,
            name: form.containerRunName(),
            command: form.commandParts(),
            volumes: form.cliVolumes(),
            ports: form.cliPorts(),
            env: form.cliEnv(),
            workdir: form.workdir.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            cpus: form.cpus.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            memory: form.memory.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            network: form.networkName.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "default",
            onOutput: onOutput
        )
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
            editContainerForm = CreateContainerForm.from(record: record, groups: containerGroups)
            showEditContainer = true
            Task { await ensureResourceListsLoaded() }
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
        isLoading = true
        defer { isLoading = false }

        do {
            let commandParts = form.commandParts()
            let effectiveCommand = commandParts.isEmpty ? editContainerOriginalCommand : commandParts
            let newID = try await recreateContainer(
                originalID: originalID,
                form: form,
                command: effectiveCommand
            )

            editContainerForm.reset()
            editContainerOriginalID = nil
            editContainerOriginalCommand = []
            showEditContainer = false
            await refreshLists(silent: false)
            selectedSection = .containers
            selectedContainerID = newID
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
        let runName = form.containerRunName()

        showCreateContainer = false
        showContainerRunProgress = true
        isContainerRunInProgress = true
        containerRunProgressOutput = ""
        containerRunProgressTitle = runName ?? form.image.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            try form.ensureHostPathsExist()

            let progressSink = makeRunProgressSink()
            let id = try await runContainerFromForm(form, onOutput: progressSink.emit)

            isContainerRunInProgress = false
            showContainerRunProgress = false
            createContainerForm.reset()
            composeImportSourceName = nil

            let selectedID = id.nilIfEmpty ?? runName ?? ""
            if !selectedID.isEmpty {
                setContainerTransition(selectedID, .creating)
            }

            assignContainerToGroup(containerID: selectedID, form: form)

            await refreshLists(silent: false)
            selectedSection = .containers
            selectedContainerID = selectedID
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

    private func makeRunProgressSink() -> MainActorProgressSink {
        MainActorProgressSink(viewModel: self)
    }
}

private final class MainActorProgressSink: @unchecked Sendable {
    private weak var viewModel: AppViewModel?

    init(viewModel: AppViewModel) {
        self.viewModel = viewModel
    }

    func emit(_ chunk: String) {
        Task { @MainActor [weak viewModel] in
            viewModel?.containerRunProgressOutput += chunk
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
