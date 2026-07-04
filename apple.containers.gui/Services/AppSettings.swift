import Foundation
import CoreGraphics

enum TerminalApplication: String, CaseIterable, Identifiable, Codable {
    case terminal
    case iterm2

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .terminal: "Terminal"
        case .iterm2: "iTerm2"
        }
    }

    var openApplicationName: String {
        switch self {
        case .terminal: "Terminal"
        case .iterm2: "iTerm"
        }
    }

    static func isInstalled(_ app: TerminalApplication) -> Bool {
        switch app {
        case .terminal:
            FileManager.default.fileExists(atPath: "/System/Applications/Utilities/Terminal.app")
        case .iterm2:
            FileManager.default.fileExists(atPath: "/Applications/iTerm.app")
        }
    }

    static var available: [TerminalApplication] {
        allCases.filter { isInstalled($0) }
    }
}

enum AppSettings {
    private static let terminalKey = "preferredTerminalApplication"
    private static let workspacePanelHeightKey = "workspacePanelHeight"
    private static let defaultDataDirectoryKey = "defaultDataDirectory"

    static let workspacePanelMinHeight: CGFloat = 160
    static let workspacePanelDefaultHeight: CGFloat = 340

    static var defaultDataDirectoryDefault: String {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents/containers-data.nosync")
            .path
    }

    static var defaultDataDirectory: String {
        get {
            if let stored = UserDefaults.standard.string(forKey: defaultDataDirectoryKey),
               !stored.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return stored
            }
            return defaultDataDirectoryDefault
        }
        set {
            UserDefaults.standard.set(newValue, forKey: defaultDataDirectoryKey)
        }
    }

    static var preferredTerminal: TerminalApplication {
        get {
            guard let raw = UserDefaults.standard.string(forKey: terminalKey),
                  let value = TerminalApplication(rawValue: raw),
                  TerminalApplication.isInstalled(value) else {
                return .terminal
            }
            return value
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: terminalKey)
        }
    }

    static var workspacePanelHeight: CGFloat {
        get {
            let stored = UserDefaults.standard.double(forKey: workspacePanelHeightKey)
            if stored > 0 {
                return CGFloat(stored)
            }
            return workspacePanelDefaultHeight
        }
        set {
            UserDefaults.standard.set(Double(newValue), forKey: workspacePanelHeightKey)
        }
    }

    static func clampWorkspacePanelHeight(_ height: CGFloat, maxHeight: CGFloat) -> CGFloat {
        min(max(AppSettings.workspacePanelMinHeight, height), maxHeight)
    }
}
