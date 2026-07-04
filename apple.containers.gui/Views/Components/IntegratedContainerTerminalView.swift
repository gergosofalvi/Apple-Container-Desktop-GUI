import AppKit
import SwiftUI
import SwiftTerm

struct IntegratedContainerTerminalView: NSViewRepresentable {
    let containerID: String
    let binaryPath: String

    func makeNSView(context: Context) -> TerminalContainerHostView {
        let host = TerminalContainerHostView()
        host.configure(containerID: containerID, binaryPath: binaryPath)
        return host
    }

    func updateNSView(_ nsView: TerminalContainerHostView, context: Context) {
        nsView.configure(containerID: containerID, binaryPath: binaryPath)
    }

    static func dismantleNSView(_ nsView: TerminalContainerHostView, coordinator: ()) {
        nsView.shutdown()
    }
}

final class TerminalContainerHostView: NSView {
    private var terminalView: LocalProcessTerminalView?
    private var hasStarted = false
    private var containerID = ""
    private var binaryPath = ""

    override var isFlipped: Bool { true }

    func configure(containerID: String, binaryPath: String) {
        self.containerID = containerID
        self.binaryPath = binaryPath
        setupIfNeeded()
        startProcessIfNeeded()
    }

    override func layout() {
        super.layout()
        terminalView?.frame = bounds
        startProcessIfNeeded()
    }

    func shutdown() {
        terminalView?.terminate()
        terminalView?.removeFromSuperview()
        terminalView = nil
        hasStarted = false
    }

    private func setupIfNeeded() {
        guard terminalView == nil else { return }
        let view = LocalProcessTerminalView(frame: bounds)
        view.autoresizingMask = [.width, .height]
        view.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        addSubview(view)
        terminalView = view
    }

    private func startProcessIfNeeded() {
        guard !hasStarted, bounds.width > 20, bounds.height > 20 else { return }
        guard let terminalView, !binaryPath.isEmpty, !containerID.isEmpty else { return }

        hasStarted = true
        terminalView.startProcess(
            executable: binaryPath,
            args: ["exec", "-it", containerID, "sh"],
            environment: nil,
            execName: nil
        )
    }
}
