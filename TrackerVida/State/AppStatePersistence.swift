import Foundation

struct PersistedAppState: Codable, Hashable {
    var schemaVersion: Int
    var weightGoal: WeightGoal
    var weightLogs: [WeightLog]
    var dailyHealthLogs: [DailyHealthLog]
    var dailyOrderPlan: AIGeneratedDailyOrderPlan
    var criticalTasks: [AcademicTask]
    var upcomingDeadlines: [AcademicTask]
    var waitingResponses: [SimpleListItem]
    var timeline: [SimpleListItem]
    var moneyAccounts: [MoneyAccount]
    var moneyTransactions: [MoneyTransaction]

    init(
        schemaVersion: Int = 1,
        weightGoal: WeightGoal,
        weightLogs: [WeightLog],
        dailyHealthLogs: [DailyHealthLog],
        dailyOrderPlan: AIGeneratedDailyOrderPlan,
        criticalTasks: [AcademicTask],
        upcomingDeadlines: [AcademicTask],
        waitingResponses: [SimpleListItem],
        timeline: [SimpleListItem],
        moneyAccounts: [MoneyAccount],
        moneyTransactions: [MoneyTransaction]
    ) {
        self.schemaVersion = schemaVersion
        self.weightGoal = weightGoal
        self.weightLogs = weightLogs
        self.dailyHealthLogs = dailyHealthLogs
        self.dailyOrderPlan = dailyOrderPlan
        self.criticalTasks = criticalTasks
        self.upcomingDeadlines = upcomingDeadlines
        self.waitingResponses = waitingResponses
        self.timeline = timeline
        self.moneyAccounts = moneyAccounts
        self.moneyTransactions = moneyTransactions
    }
}

enum AppStatePersistenceError: Error, Equatable {
    case documentsDirectoryUnavailable
    case loadFailed(String)
    case saveFailed(String)
}

protocol AppStatePersisting {
    func load() throws -> PersistedAppState?
    func save(_ state: PersistedAppState) throws
}

struct JSONFileAppStatePersistence: AppStatePersisting {
    private let fileURL: URL
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let fileManager: FileManager

    init(fileURL: URL, fileManager: FileManager = .default) {
        self.fileURL = fileURL
        self.fileManager = fileManager

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder
    }

    static func live(fileManager: FileManager = .default) throws -> JSONFileAppStatePersistence {
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw AppStatePersistenceError.documentsDirectoryUnavailable
        }

        return JSONFileAppStatePersistence(
            fileURL: documentsURL.appendingPathComponent("tracker-vida-state.json"),
            fileManager: fileManager
        )
    }

    func load() throws -> PersistedAppState? {
        guard fileManager.fileExists(atPath: fileURL.path) else { return nil }

        do {
            let data = try Data(contentsOf: fileURL)
            return try decoder.decode(PersistedAppState.self, from: data)
        } catch {
            throw AppStatePersistenceError.loadFailed(error.localizedDescription)
        }
    }

    func save(_ state: PersistedAppState) throws {
        do {
            let directoryURL = fileURL.deletingLastPathComponent()
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)

            let data = try encoder.encode(state)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            throw AppStatePersistenceError.saveFailed(error.localizedDescription)
        }
    }
}
