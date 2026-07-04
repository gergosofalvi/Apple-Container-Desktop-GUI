import SwiftUI

@main
struct AppleContainerDesktopApp: App {
    @State private var model = AppViewModel()

    var body: some Scene {
        WindowGroup("Apple Container Desktop") {
            ContentView()
                .environment(model)
        }
        .defaultSize(width: 1100, height: 720)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Run Container…") {
                    model.prepareCreateContainerSheet()
                }
                .keyboardShortcut("n", modifiers: [.command])

                Button("Create Machine…") {
                    model.prepareCreateMachineSheet()
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            }

            CommandGroup(after: .toolbar) {
                Button("Refresh") {
                    Task { await model.refreshAll() }
                }
                .keyboardShortcut("r", modifiers: [.command])
            }

            CommandGroup(replacing: .appSettings) {
                Button("Settings…") {
                    model.selectedSection = .settings
                }
                .keyboardShortcut(",", modifiers: [.command])
            }
        }
    }
}
