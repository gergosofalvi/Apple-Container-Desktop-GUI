import SwiftUI

struct IconActionButton: View {
    let title: String
    let systemImage: String
    let tint: Color
    var role: ButtonRole?
    var disabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(role: role, action: action) {
            Label(title, systemImage: systemImage)
                .font(.callout.weight(.semibold))
                .padding(.horizontal, 4)
        }
        .buttonStyle(.bordered)
        .tint(tint)
        .disabled(disabled)
    }
}

struct ContainerActionButtons: View {
    @Environment(AppViewModel.self) private var model
    let containerID: String
    let isRunning: Bool
    let isTransitioning: Bool

    var body: some View {
        DetailActionBar {
            if isTransitioning {
                IconActionButton(
                    title: "Wait",
                    systemImage: "hourglass",
                    tint: .yellow,
                    disabled: true
                ) {}
            } else if isRunning {
                IconActionButton(
                    title: "Stop",
                    systemImage: "stop.fill",
                    tint: .orange
                ) {
                    Task { await model.stopSelectedContainer() }
                }
            } else {
                IconActionButton(
                    title: "Start",
                    systemImage: "play.fill",
                    tint: .green
                ) {
                    Task { await model.startSelectedContainer() }
                }
            }

            IconActionButton(
                title: "Logs",
                systemImage: "doc.text.fill",
                tint: .blue
            ) {
                model.openWorkspaceLogs(for: containerID)
            }

            IconActionButton(
                title: "Exec",
                systemImage: "terminal.fill",
                tint: .purple
            ) {
                model.openWorkspaceExec(for: containerID)
            }

            IconActionButton(
                title: "Export",
                systemImage: "square.and.arrow.up",
                tint: .teal
            ) {
                Task { await model.exportSelectedContainerToCompose() }
            }

            IconActionButton(
                title: "Edit",
                systemImage: "slider.horizontal.3",
                tint: .accentColor
            ) {
                Task { await model.prepareEditContainerSheet() }
            }

            IconActionButton(
                title: "Delete",
                systemImage: "trash.fill",
                tint: .red,
                role: .destructive
            ) {
                Task { await model.deleteSelectedContainer() }
            }
        }
    }
}
