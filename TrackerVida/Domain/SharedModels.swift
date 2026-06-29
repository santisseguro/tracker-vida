import Foundation

typealias EntityID = UUID

enum AppArea: String, CaseIterable, Codable, Identifiable {
    case dashboard
    case gymHealth
    case university
    case money
    case settings
    case dailyOrders

    var id: String { rawValue }
}

enum PriorityLevel: String, CaseIterable, Codable, Identifiable {
    case low
    case medium
    case high
    case urgent

    var id: String { rawValue }
}

enum CompletionStatus: String, CaseIterable, Codable, Identifiable {
    case pending
    case inProgress
    case done
    case skipped

    var id: String { rawValue }
}

struct BaseMetadata: Codable, Hashable {
    var id: EntityID
    var createdAt: Date
    var updatedAt: Date
    var archivedAt: Date?

    init(id: EntityID = UUID(), createdAt: Date = .now, updatedAt: Date = .now, archivedAt: Date? = nil) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.archivedAt = archivedAt
    }
}

struct LinkedResource: Codable, Hashable, Identifiable {
    var id: EntityID = UUID()
    var label: String
    var url: URL
}
