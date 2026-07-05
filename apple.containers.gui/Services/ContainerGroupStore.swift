import Foundation

enum ContainerGroupStore {
    private static let storageKey = "containerGroups"

    static func load() -> [ContainerGroup] {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return [] }
        return (try? JSONDecoder().decode([ContainerGroup].self, from: data)) ?? []
    }

    static func save(_ groups: [ContainerGroup]) {
        guard let data = try? JSONEncoder().encode(groups) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
