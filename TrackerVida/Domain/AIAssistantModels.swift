import Foundation

enum AIAssistantIntentKind: String, Codable, Hashable, CaseIterable, Identifiable {
    case readOnlyQuestion
    case action
    case pendingFollowUp
    case unknown

    var id: String { rawValue }
}

enum AIReadOnlyQuestionTopic: String, Codable, Hashable, CaseIterable, Identifiable {
    case dailyPriorities
    case healthProgress
    case universitySchedule
    case universityTasks
    case moneySummary
    case moneySpending
    case crossSectionSummary
    case unknown

    var id: String { rawValue }
}

struct AIAssistantRequest: Codable, Hashable, Identifiable {
    var id: EntityID
    var section: AICommandContext
    var text: String
    var createdAt: Date
    var pendingFollowUpID: EntityID?

    init(
        id: EntityID = EntityID(),
        section: AICommandContext,
        text: String,
        createdAt: Date = .now,
        pendingFollowUpID: EntityID? = nil
    ) {
        self.id = id
        self.section = section
        self.text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        self.createdAt = createdAt
        self.pendingFollowUpID = pendingFollowUpID
    }
}

struct AIReadOnlyQuestionIntent: Codable, Hashable {
    var section: AICommandContext
    var question: String
    var topic: AIReadOnlyQuestionTopic

    init(section: AICommandContext, question: String, topic: AIReadOnlyQuestionTopic = .unknown) {
        self.section = section
        self.question = question.trimmingCharacters(in: .whitespacesAndNewlines)
        self.topic = topic
    }
}

struct AIActionIntent: Codable, Hashable {
    var section: AICommandContext
    var actionName: String
    var arguments: [String: String]
    var requiresConfirmation: Bool
    var confidence: Double?

    init(
        section: AICommandContext,
        actionName: String,
        arguments: [String: String] = [:],
        requiresConfirmation: Bool,
        confidence: Double? = nil
    ) {
        self.section = section
        self.actionName = actionName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.arguments = arguments
        self.requiresConfirmation = requiresConfirmation
        self.confidence = confidence
    }
}

struct AIPendingFollowUpIntent: Codable, Hashable, Identifiable {
    var id: EntityID
    var section: AICommandContext
    var originalText: String
    var prompt: String
    var missingFields: [String]
    var proposedAction: AIActionIntent?
    var createdAt: Date

    init(
        id: EntityID = EntityID(),
        section: AICommandContext,
        originalText: String,
        prompt: String,
        missingFields: [String],
        proposedAction: AIActionIntent? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.section = section
        self.originalText = originalText.trimmingCharacters(in: .whitespacesAndNewlines)
        self.prompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        self.missingFields = missingFields
        self.proposedAction = proposedAction
        self.createdAt = createdAt
    }
}

enum AIAssistantIntent: Codable, Hashable {
    case readOnlyQuestion(AIReadOnlyQuestionIntent)
    case action(AIActionIntent)
    case pendingFollowUp(AIPendingFollowUpIntent)
    case unknown(String)

    var kind: AIAssistantIntentKind {
        switch self {
        case .readOnlyQuestion:
            return .readOnlyQuestion
        case .action:
            return .action
        case .pendingFollowUp:
            return .pendingFollowUp
        case .unknown:
            return .unknown
        }
    }

    private enum CodingKeys: String, CodingKey {
        case kind
        case readOnlyQuestion
        case action
        case pendingFollowUp
        case unknownText
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(AIAssistantIntentKind.self, forKey: .kind)

        switch kind {
        case .readOnlyQuestion:
            self = .readOnlyQuestion(try container.decode(AIReadOnlyQuestionIntent.self, forKey: .readOnlyQuestion))
        case .action:
            self = .action(try container.decode(AIActionIntent.self, forKey: .action))
        case .pendingFollowUp:
            self = .pendingFollowUp(try container.decode(AIPendingFollowUpIntent.self, forKey: .pendingFollowUp))
        case .unknown:
            self = .unknown(try container.decode(String.self, forKey: .unknownText))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind, forKey: .kind)

        switch self {
        case .readOnlyQuestion(let intent):
            try container.encode(intent, forKey: .readOnlyQuestion)
        case .action(let intent):
            try container.encode(intent, forKey: .action)
        case .pendingFollowUp(let intent):
            try container.encode(intent, forKey: .pendingFollowUp)
        case .unknown(let text):
            try container.encode(text, forKey: .unknownText)
        }
    }
}

struct AIProviderResponse: Codable, Hashable {
    var providerName: String
    var modelName: String?
    var isLocal: Bool
    var rawText: String?
    var structuredVersion: String

    static let localStub = AIProviderResponse(
        providerName: "LocalAIAssistantService",
        modelName: nil,
        isLocal: true,
        rawText: nil,
        structuredVersion: "assistant-foundation-v1"
    )
}

struct AIAssistantResult: Codable, Hashable, Identifiable {
    var id: EntityID
    var requestID: EntityID
    var section: AICommandContext
    var intent: AIAssistantIntent
    var response: String
    var requiresFollowUp: Bool
    var completedActionSummary: String?
    var providerResponse: AIProviderResponse?
    var createdAt: Date

    init(
        id: EntityID = EntityID(),
        requestID: EntityID,
        section: AICommandContext,
        intent: AIAssistantIntent,
        response: String,
        requiresFollowUp: Bool = false,
        completedActionSummary: String? = nil,
        providerResponse: AIProviderResponse? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.requestID = requestID
        self.section = section
        self.intent = intent
        self.response = response.trimmingCharacters(in: .whitespacesAndNewlines)
        self.requiresFollowUp = requiresFollowUp
        self.completedActionSummary = completedActionSummary
        self.providerResponse = providerResponse
        self.createdAt = createdAt
    }
}

struct AISectionContext: Codable, Hashable {
    var section: AICommandContext
    var generatedAt: Date
    var dashboard: AIDashboardAssistantContext?
    var gymHealth: AIGymHealthAssistantContext?
    var university: AIUniversityAssistantContext?
    var money: AIMoneyAssistantContext?
}

struct AIDashboardAssistantContext: Codable, Hashable {
    var latestWeightKg: Double?
    var todayCalories: Int?
    var weeklyGymCount: Int
    var dailyOrderTitle: String?
    var dailyOrderSummary: String?
    var dailyOrderCompletionRatio: Double
    var dailyOrderCompletedItems: Int
    var dailyOrderTotalItems: Int
    var activeCriticalTaskCount: Int
    var upcomingDeadlineCount: Int
    var moneyTotals: AIMoneyTotalsContext
}

struct AIGymHealthAssistantContext: Codable, Hashable {
    var currentWeightKg: Double?
    var sevenDayAverageWeightKg: Double?
    var targetWeightKg: Double
    var weightRemainingKg: Double?
    var todayCalories: Int?
    var dailyCalorieTarget: Int
    var dailyCalorieDelta: Int?
    var weeklyCalorieTarget: Int
    var weeklyCaloriesConsumed: Int
    var weeklyCalorieDelta: Int
    var estimatedWeightImpactKg: Double
    var estimatedTargetDate: Date?
    var completedWorkouts: Int
    var targetWorkouts: Int
    var trackStatus: GymHealthTrackStatus
    var averageSleepHours: Double
    var dailyOrderTitle: String?
    var dailyOrderSummary: String?
    var checklistItems: [AIChecklistItemContext]
}

struct AIUniversityAssistantContext: Codable, Hashable {
    var activeCriticalTasks: [AIAcademicTaskContext]
    var upcomingDeadlines: [AIAcademicTaskContext]
    var waitingResponses: [AIListItemContext]
    var timeline: [AIListItemContext]
    var classes: [AIUniversityClassContext]
    var todayClasses: [AIUniversityScheduledClassContext]
    var upcomingClassesThisWeek: [AIUniversityScheduledClassContext]
}

struct AIMoneyAssistantContext: Codable, Hashable {
    var accounts: [AIMoneyAccountContext]
    var accountBalances: [AIListItemContext]
    var recentTransactions: [AIMoneyTransactionContext]
    var totals: AIMoneyTotalsContext
}

struct AIChecklistItemContext: Codable, Hashable, Identifiable {
    var id: EntityID
    var title: String
    var status: DailyOrderStatus
    var priority: PriorityLevel
    var area: AppArea
}

struct AIAcademicTaskContext: Codable, Hashable, Identifiable {
    var id: EntityID
    var title: String
    var category: AcademicTaskCategory
    var status: AcademicTaskStatus
    var priority: AcademicTaskPriority
    var dueDate: Date?
    var waitingSince: Date?
    var notes: String?
}

struct AIListItemContext: Codable, Hashable, Identifiable {
    var id: EntityID
    var title: String
    var detail: String
    var value: String
}

struct AIUniversityClassContext: Codable, Hashable, Identifiable {
    var id: EntityID
    var name: String
    var shortName: String?
    var instructor: String?
    var location: String?
    var color: UniversityClassColor?
}

struct AIUniversityScheduledClassContext: Codable, Hashable, Identifiable {
    var id: EntityID
    var classID: EntityID
    var className: String
    var weekday: UniversityWeekday
    var occurrenceDate: Date
    var startMinuteOfDay: Int
    var endMinuteOfDay: Int
    var location: String?
}

struct AIMoneyAccountContext: Codable, Hashable, Identifiable {
    var id: EntityID
    var name: String
    var currency: CurrencyCode
    var balanceMinorUnits: Int
    var kind: MoneyAccountKind
    var color: MoneyAccountColor
}

struct AIMoneyTransactionContext: Codable, Hashable, Identifiable {
    var id: EntityID
    var date: Date
    var title: String
    var kind: MoneyTransactionKind
    var amount: MoneyAmount
    var fromAccountID: EntityID?
    var toAccountID: EntityID?
    var categoryLabel: String?
    var notes: String?
}

struct AIMoneyTotalsContext: Codable, Hashable {
    var arsMinorUnits: Int
    var usdtMinorUnits: Int
    var arsEquivalentMinorUnits: Int
    var mockUSDTToARSRate: Int
}

