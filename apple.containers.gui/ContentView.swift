import SwiftUI

struct ContentView: View {
    @Environment(AppViewModel.self) private var model

    var body: some View {
        @Bindable var model = model

        GeometryReader { geometry in
            let maxPanelHeight = max(
                AppSettings.workspacePanelMinHeight,
                geometry.size.height - 120
            )
            let panelHeight = model.isCLIInstalled && model.isWorkspacePanelOpen
                ? AppSettings.clampWorkspacePanelHeight(model.workspacePanelHeight, maxHeight: maxPanelHeight)
                : 0
            let handleHeight: CGFloat = model.isCLIInstalled && model.isWorkspacePanelOpen ? 10 : 0
            let mainHeight = max(0, geometry.size.height - panelHeight - handleHeight)

            VStack(spacing: 0) {
                Group {
                    if model.isCLIInstalled {
                        NavigationSplitView {
                            SectionSidebarView()
                                .navigationSplitViewColumnWidth(min: 140, ideal: 170, max: 200)
                        } content: {
                            itemList
                                .navigationSplitViewColumnWidth(min: 240, ideal: 300, max: 380)
                        } detail: {
                            itemDetail
                        }
                        .navigationSplitViewStyle(.balanced)
                    } else {
                        InstallRequiredView()
                    }
                }
                .frame(height: mainHeight)

                if model.isCLIInstalled && model.isWorkspacePanelOpen {
                    VerticalPanelResizeHandle(
                        height: $model.workspacePanelHeight,
                        maxHeight: maxPanelHeight
                    )

                    ContainerWorkspacePanel()
                        .frame(height: panelHeight)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
            .onAppear {
                model.workspacePanelHeight = AppSettings.clampWorkspacePanelHeight(
                    model.workspacePanelHeight,
                    maxHeight: maxPanelHeight
                )
            }
            .onChange(of: maxPanelHeight) { _, updatedMax in
                if model.workspacePanelHeight > updatedMax {
                    model.workspacePanelHeight = updatedMax
                }
            }
        }
        .animation(.easeInOut(duration: 0.22), value: model.isWorkspacePanelOpen)
        .frame(minWidth: 900, minHeight: 600)
        .overlay(alignment: .top) {
            if let toast = model.toast {
                AppToastView(
                    message: toast.message,
                    onDismiss: { model.dismissToast() },
                    onCopy: { model.copyToastToClipboard() }
                )
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(100)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: model.toast?.id)
        .safeAreaInset(edge: .bottom) {
            if let errorMessage = model.errorMessage {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text(errorMessage)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Button("Dismiss") {
                            model.errorMessage = nil
                            model.errorTerminalCommand = nil
                        }
                    }

                    if let command = model.errorTerminalCommand {
                        HStack {
                            Text(command)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .lineLimit(2)
                            Spacer()
                            Button("Open Terminal") {
                                model.openErrorTerminalCommand()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }
                .font(.callout)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.bar)
            }
        }
        .sheet(isPresented: $model.showInstallSheet) {
            InstallRequiredView()
        }
        .sheet(isPresented: $model.showCreateContainer) {
            CreateContainerSheet()
        }
        .sheet(isPresented: $model.showContainerRunProgress) {
            ContainerRunProgressSheet()
        }
        .sheet(isPresented: $model.showEditContainer) {
            EditContainerSheet()
        }
        .sheet(isPresented: $model.showCreateMachine) {
            CreateMachineSheet()
        }
        .sheet(isPresented: $model.showCreateVolume) {
            CreateVolumeSheet()
        }
        .sheet(isPresented: $model.showCreateNetwork) {
            CreateNetworkSheet()
        }
        .sheet(isPresented: $model.showImportComposePicker) {
            if let document = model.importComposeServiceNames, !document.isEmpty {
                ImportComposeSheet(serviceNames: document)
            }
        }
        .task {
            await model.bootstrap()
        }
    }

    @ViewBuilder
    private var itemList: some View {
        switch model.selectedSection {
        case .containers:
            ContainerListPanel()
        case .volumes:
            VolumeListPanel()
        case .networks:
            NetworkListPanel()
        case .machines:
            MachineListPanel()
        case .settings:
            SettingsListPanel()
        }
    }

    @ViewBuilder
    private var itemDetail: some View {
        switch model.selectedSection {
        case .containers:
            if let container = model.selectedContainer {
                ContainerDetailView(container: container)
            } else {
                EmptyStateView(
                    title: "No Container Selected",
                    subtitle: "Run a container or select one from the list.",
                    systemImage: "shippingbox",
                    actionTitle: "Run Container"
                ) {
                    model.prepareCreateContainerSheet()
                }
            }
        case .volumes:
            if let volume = model.selectedVolume {
                VolumeDetailView(volume: volume)
            } else {
                EmptyStateView(
                    title: "No Volume Selected",
                    subtitle: "Select a volume to inspect usage and delete it.",
                    systemImage: "externaldrive",
                    actionTitle: "Create Volume"
                ) {
                    model.prepareCreateVolumeSheet()
                }
            }
        case .networks:
            if let network = model.selectedNetwork {
                NetworkDetailView(network: network)
            } else {
                EmptyStateView(
                    title: "No Network Selected",
                    subtitle: "Create a network or select one to see connected containers.",
                    systemImage: "network",
                    actionTitle: "Create Network"
                ) {
                    model.prepareCreateNetworkSheet()
                }
            }
        case .machines:
            if let machine = model.selectedMachine {
                MachineDetailView(machine: machine)
            } else {
                EmptyStateView(
                    title: "No Machine Selected",
                    subtitle: "Create a container machine for a persistent Linux environment.",
                    systemImage: "desktopcomputer",
                    actionTitle: "Create Machine"
                ) {
                    model.prepareCreateMachineSheet()
                }
            }
        case .settings:
            SettingsView()
        }
    }
}

private struct SectionSidebarView: View {
    @Environment(AppViewModel.self) private var model

    var body: some View {
        @Bindable var model = model

        List(selection: $model.selectedSection) {
            ForEach(SidebarSection.allCases) { section in
                Label(section.rawValue, systemImage: section.icon)
                    .tag(section)
            }
        }
        .navigationTitle("Apple Container")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                if model.isLoading {
                    ProgressView()
                        .controlSize(.small)
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(AppViewModel())
}
