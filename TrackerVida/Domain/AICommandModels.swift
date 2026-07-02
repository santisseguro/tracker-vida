import Foundation

enum AICommandContext: String, CaseIterable, Codable, Identifiable {
    case dashboard
    case gymHealth
    case university
    case money

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard:
            return "Dashboard"
        case .gymHealth:
            return "Gym / Health"
        case .university:
            return "University"
        case .money:
            return "Money"
        }
    }
}

struct CapturedAICommand: Codable, Hashable, Identifiable {
    var id: EntityID
    var context: AICommandContext
    var text: String
    var createdAt: Date

    init(id: EntityID = EntityID(), context: AICommandContext, text: String, createdAt: Date = .now) {
        self.id = id
        self.context = context
        self.text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        self.createdAt = createdAt
    }

    var confirmationText: String {
        "Captured for \(context.title)"
    }
}
