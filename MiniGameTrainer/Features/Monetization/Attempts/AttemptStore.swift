import Foundation

/// UserDefaults-backed daily attempt records. Mirrors `StatisticsStore` persistence style.
@MainActor
final class AttemptStore {
    private let userDefaults: UserDefaults
    private let storageKey: String
    private let version: Int

    init(
        userDefaults: UserDefaults = .standard,
        storageKey: String = MonetizationConfiguration.persistenceKey,
        version: Int = MonetizationConfiguration.persistenceVersion
    ) {
        self.userDefaults = userDefaults
        self.storageKey = storageKey
        self.version = version
    }

    func load() -> [String: DailyAttemptRecord] {
        guard let data = userDefaults.data(forKey: storageKey) else { return [:] }
        do {
            let box = try JSONDecoder().decode(AttemptPersistenceBox.self, from: data)
            guard box.version == version else {
                MonetizationLog.debug("Attempt store version \(box.version) != \(version); resetting")
                return [:]
            }
            return box.records
        } catch {
            MonetizationLog.debug("Attempt store decode failed; resetting")
            return [:]
        }
    }

    func save(_ records: [String: DailyAttemptRecord]) {
        let box = AttemptPersistenceBox(version: version, records: records)
        guard let data = try? JSONEncoder().encode(box) else {
            MonetizationLog.debug("Attempt store encode failed")
            return
        }
        userDefaults.set(data, forKey: storageKey)
    }
}
