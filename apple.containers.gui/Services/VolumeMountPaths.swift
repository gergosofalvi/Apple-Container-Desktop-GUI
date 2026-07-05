import Foundation

enum VolumeMountPaths {
    static var defaultDataDirectory: String {
        get { AppSettings.defaultDataDirectory }
        set { AppSettings.defaultDataDirectory = newValue }
    }

    static var defaultDataDirectoryURL: URL {
        URL(fileURLWithPath: expandedDefaultDataDirectory, isDirectory: true)
    }

    static var expandedDefaultDataDirectory: String {
        (defaultDataDirectory as NSString).expandingTildeInPath
    }

    static func resolvePresetHostPath(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }

        if trimmed.hasPrefix("/") {
            return trimmed
        }

        let base = expandedDefaultDataDirectory

        if trimmed.hasPrefix("~/container-data/") {
            let suffix = String(trimmed.dropFirst("~/container-data/".count))
            return (base as NSString).appendingPathComponent(suffix)
        }

        if trimmed.hasPrefix("~/Projects/") {
            let suffix = String(trimmed.dropFirst("~/Projects/".count))
            return (base as NSString).appendingPathComponent(suffix)
        }

        if trimmed.hasPrefix("~/") {
            let suffix = String(trimmed.dropFirst(2))
            return (base as NSString).appendingPathComponent(suffix)
        }

        return (base as NSString).appendingPathComponent(trimmed)
    }

    static func ensureDirectoryExists(at path: String) throws {
        let expanded = (path as NSString).expandingTildeInPath
        guard !expanded.isEmpty else { return }
        guard expanded.hasPrefix("/") else { return }

        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: expanded, isDirectory: &isDirectory) {
            if !isDirectory.boolValue {
                throw VolumeMountError.notADirectory(expanded)
            }
            return
        }

        try fileManager.createDirectory(atPath: expanded, withIntermediateDirectories: true)
    }

    static func ensureHostPathsExist(for mounts: [VolumeMount]) throws {
        for mount in mounts where mount.kind == .bind {
            let rawPath = mount.hostPath.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !rawPath.isEmpty else { continue }
            guard rawPath.hasPrefix("/") || rawPath.hasPrefix("~") else { continue }
            try ensureDirectoryExists(at: rawPath)
        }
    }
}
