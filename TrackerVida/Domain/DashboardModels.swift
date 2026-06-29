import Foundation

enum DashboardCardKind: String, CaseIterable, Codable, Identifiable {
    case summary = "Summary"
    case reminder = "Reminder"
    case progress = "Progress"
    case emptyState = "Empty State"

    var id: String { rawValue }
}

enum DashboardCardStatus: String, CaseIterable, Codable, Identifiable {
    case normal = "Normal"
    case attention = "Attention"
    case urgent = "Urgent"
    case complete = "Complete"

    var id: String { rawValue }
}

struct DashboardCardModel: Codable, Hashable, Identifiable {
    var metadata: BaseMetadata
    var area: AppArea
    var kind: DashboardCardKind
    var status: DashboardCardStatus
    var title: String
    var description: String? = nil
    var priority: PriorityLevel
    var sortOrder: Int
    var targetDate: Date? = nil
    var sourceEntityID: EntityID? = nil

    var id: EntityID { metadata.id }
}

struct DashboardSnapshot: Codable, Hashable {
    var date: Date
    var cards: [DashboardCardModel]
}
