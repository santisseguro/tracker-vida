import Foundation

enum DailyOrderSource: String, CaseIterable, Codable, Identifiable {
    case manualDraft = "Manual Draft"
    case aiGenerated = "AI Generated"

    var id: String { rawValue }
}

enum DailyOrderStatus: String, CaseIterable, Codable, Identifiable {
    case pending = "Pending"
    case inProgress = "In Progress"
    case done = "Done"
    case skipped = "Skipped"

    var id: String { rawValue }
}

enum DailyOrderItemKind: String, CaseIterable, Codable, Identifiable {
    case task = "Task"
    case reminder = "Reminder"
    case review = "Review"

    var id: String { rawValue }
}

struct DailyChecklistItem: Codable, Hashable, Identifiable {
    var id: EntityID = UUID()
    var title: String
    var kind: DailyOrderItemKind
    var area: AppArea
    var status: DailyOrderStatus
    var priority: PriorityLevel
    var sourceEntityID: EntityID? = nil
    var rationale: String? = nil
}

struct DailyOrder: Codable, Hashable, Identifiable {
    var metadata: BaseMetadata
    var title: String
    var area: AppArea
    var status: DailyOrderStatus
    var priority: PriorityLevel
    var checklist: [DailyChecklistItem]
    var sourceEntityIDs: [EntityID] = []

    var id: EntityID { metadata.id }
}

struct AIGeneratedDailyOrderPlan: Codable, Hashable, Identifiable {
    var metadata: BaseMetadata
    var date: Date
    var source: DailyOrderSource
    var generatedAt: Date? = nil
    var promptVersion: String? = nil
    var summary: String? = nil
    var orders: [DailyOrder]

    var id: EntityID { metadata.id }

    var completionRatio: Double {
        let items = orders.flatMap(\.checklist)
        guard !items.isEmpty else { return 0 }
        let completed = items.filter { $0.status == .done || $0.status == .skipped }.count
        return Double(completed) / Double(items.count)
    }
}
