import Foundation

struct SupabaseAppOwnerDTO: Codable, Hashable, Identifiable {
    var id: EntityID
    var displayName: String?
    var timezoneIdentifier: String
    var schemaVersion: Int
    var createdAt: Date
    var updatedAt: Date

    private enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case timezoneIdentifier = "timezone_identifier"
        case schemaVersion = "schema_version"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct SupabaseHealthWeightGoalDTO: Codable, Hashable, Identifiable {
    var id: EntityID
    var ownerID: EntityID
    var targetWeightKg: Double
    var startWeightKg: Double?
    var startDate: Date
    var targetDate: Date?
    var gymDayCalorieTarget: Int
    var restDayCalorieTarget: Int
    var targetWorkoutsPerWeek: Int
    var idealGymWeekdays: [Int]
    var isActive: Bool
    var notes: String?
    var createdAt: Date
    var updatedAt: Date
    var archivedAt: Date?

    private enum CodingKeys: String, CodingKey {
        case id
        case ownerID = "owner_id"
        case targetWeightKg = "target_weight_kg"
        case startWeightKg = "start_weight_kg"
        case startDate = "start_date"
        case targetDate = "target_date"
        case gymDayCalorieTarget = "gym_day_calorie_target"
        case restDayCalorieTarget = "rest_day_calorie_target"
        case targetWorkoutsPerWeek = "target_workouts_per_week"
        case idealGymWeekdays = "ideal_gym_weekdays"
        case isActive = "is_active"
        case notes
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case archivedAt = "archived_at"
    }
}

struct SupabaseHealthWeightLogDTO: Codable, Hashable, Identifiable {
    var id: EntityID
    var ownerID: EntityID
    var logDate: Date
    var weightKg: Double
    var source: String
    var sourceImportedAt: Date?
    var sourceExternalID: String?
    var sourceDeviceName: String?
    var isLateEntry: Bool
    var originalEntryDate: Date?
    var enteredAt: Date?
    var lateEntryReason: String?
    var notes: String?
    var createdAt: Date
    var updatedAt: Date
    var archivedAt: Date?

    private enum CodingKeys: String, CodingKey {
        case id
        case ownerID = "owner_id"
        case logDate = "log_date"
        case weightKg = "weight_kg"
        case source
        case sourceImportedAt = "source_imported_at"
        case sourceExternalID = "source_external_id"
        case sourceDeviceName = "source_device_name"
        case isLateEntry = "is_late_entry"
        case originalEntryDate = "original_entry_date"
        case enteredAt = "entered_at"
        case lateEntryReason = "late_entry_reason"
        case notes
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case archivedAt = "archived_at"
    }
}

struct SupabaseHealthDailyLogDTO: Codable, Hashable, Identifiable {
    var id: EntityID
    var ownerID: EntityID
    var logDate: Date
    var totalCalories: Int?
    var gymAttended: Bool
    var workoutDurationMinutes: Int?
    var workoutType: String?
    var sleepHours: Double?
    var sleepQuality: String?
    var source: String
    var sourceImportedAt: Date?
    var sourceExternalID: String?
    var sourceDeviceName: String?
    var isLateEntry: Bool
    var originalEntryDate: Date?
    var enteredAt: Date?
    var lateEntryReason: String?
    var notes: String?
    var createdAt: Date
    var updatedAt: Date
    var archivedAt: Date?

    private enum CodingKeys: String, CodingKey {
        case id
        case ownerID = "owner_id"
        case logDate = "log_date"
        case totalCalories = "total_calories"
        case gymAttended = "gym_attended"
        case workoutDurationMinutes = "workout_duration_minutes"
        case workoutType = "workout_type"
        case sleepHours = "sleep_hours"
        case sleepQuality = "sleep_quality"
        case source
        case sourceImportedAt = "source_imported_at"
        case sourceExternalID = "source_external_id"
        case sourceDeviceName = "source_device_name"
        case isLateEntry = "is_late_entry"
        case originalEntryDate = "original_entry_date"
        case enteredAt = "entered_at"
        case lateEntryReason = "late_entry_reason"
        case notes
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case archivedAt = "archived_at"
    }
}

struct SupabaseUniversityTaskDTO: Codable, Hashable, Identifiable {
    var id: EntityID
    var ownerID: EntityID
    var courseID: EntityID?
    var title: String
    var category: String
    var status: String
    var priority: String
    var dueDate: Date?
    var waitingSince: Date?
    var completedAt: Date?
    var notes: String?
    var links: [LinkedResource]
    var createdAt: Date
    var updatedAt: Date
    var archivedAt: Date?

    private enum CodingKeys: String, CodingKey {
        case id
        case ownerID = "owner_id"
        case courseID = "course_id"
        case title
        case category
        case status
        case priority
        case dueDate = "due_date"
        case waitingSince = "waiting_since"
        case completedAt = "completed_at"
        case notes
        case links
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case archivedAt = "archived_at"
    }
}

struct SupabaseMoneyAccountDTO: Codable, Hashable, Identifiable {
    var id: EntityID
    var ownerID: EntityID
    var name: String
    var currency: String
    var currentBalanceMinorUnits: Int
    var kind: String
    var status: String
    var notes: String?
    var createdAt: Date
    var updatedAt: Date
    var archivedAt: Date?

    private enum CodingKeys: String, CodingKey {
        case id
        case ownerID = "owner_id"
        case name
        case currency
        case currentBalanceMinorUnits = "current_balance_minor_units"
        case kind
        case status
        case notes
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case archivedAt = "archived_at"
    }
}

struct SupabaseMoneyTransactionDTO: Codable, Hashable, Identifiable {
    var id: EntityID
    var ownerID: EntityID
    var transactionDate: Date
    var title: String
    var kind: String
    var amountMinorUnits: Int
    var amountCurrency: String
    var fromAccountID: EntityID?
    var toAccountID: EntityID?
    var categoryKind: String?
    var categoryLabel: String?
    var balanceBeforeMinorUnits: Int?
    var balanceBeforeCurrency: String?
    var balanceAfterMinorUnits: Int?
    var balanceAfterCurrency: String?
    var notes: String?
    var createdAt: Date
    var updatedAt: Date
    var archivedAt: Date?

    private enum CodingKeys: String, CodingKey {
        case id
        case ownerID = "owner_id"
        case transactionDate = "transaction_date"
        case title
        case kind
        case amountMinorUnits = "amount_minor_units"
        case amountCurrency = "amount_currency"
        case fromAccountID = "from_account_id"
        case toAccountID = "to_account_id"
        case categoryKind = "category_kind"
        case categoryLabel = "category_label"
        case balanceBeforeMinorUnits = "balance_before_minor_units"
        case balanceBeforeCurrency = "balance_before_currency"
        case balanceAfterMinorUnits = "balance_after_minor_units"
        case balanceAfterCurrency = "balance_after_currency"
        case notes
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case archivedAt = "archived_at"
    }
}

struct SupabaseDailyOrderPlanDTO: Codable, Hashable, Identifiable {
    var id: EntityID
    var ownerID: EntityID
    var planDate: Date
    var source: String
    var generatedAt: Date?
    var promptVersion: String?
    var summary: String?
    var createdAt: Date
    var updatedAt: Date
    var archivedAt: Date?

    private enum CodingKeys: String, CodingKey {
        case id
        case ownerID = "owner_id"
        case planDate = "plan_date"
        case source
        case generatedAt = "generated_at"
        case promptVersion = "prompt_version"
        case summary
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case archivedAt = "archived_at"
    }
}

struct SupabaseDailyOrderDTO: Codable, Hashable, Identifiable {
    var id: EntityID
    var ownerID: EntityID
    var planID: EntityID
    var title: String
    var area: String
    var status: String
    var priority: String
    var sourceEntityIDs: [EntityID]
    var createdAt: Date
    var updatedAt: Date
    var archivedAt: Date?

    private enum CodingKeys: String, CodingKey {
        case id
        case ownerID = "owner_id"
        case planID = "plan_id"
        case title
        case area
        case status
        case priority
        case sourceEntityIDs = "source_entity_ids"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case archivedAt = "archived_at"
    }
}

struct SupabaseDailyChecklistItemDTO: Codable, Hashable, Identifiable {
    var id: EntityID
    var ownerID: EntityID
    var orderID: EntityID
    var title: String
    var kind: String
    var area: String
    var status: String
    var priority: String
    var sourceEntityID: EntityID?
    var rationale: String?
    var createdAt: Date
    var updatedAt: Date
    var archivedAt: Date?

    private enum CodingKeys: String, CodingKey {
        case id
        case ownerID = "owner_id"
        case orderID = "order_id"
        case title
        case kind
        case area
        case status
        case priority
        case sourceEntityID = "source_entity_id"
        case rationale
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case archivedAt = "archived_at"
    }
}

struct SupabaseAppStateDTO: Codable, Hashable {
    var owner: SupabaseAppOwnerDTO
    var weightGoal: SupabaseHealthWeightGoalDTO
    var weightLogs: [SupabaseHealthWeightLogDTO]
    var dailyHealthLogs: [SupabaseHealthDailyLogDTO]
    var universityTasks: [SupabaseUniversityTaskDTO]
    var moneyAccounts: [SupabaseMoneyAccountDTO]
    var moneyTransactions: [SupabaseMoneyTransactionDTO]
    var dailyOrderPlan: SupabaseDailyOrderPlanDTO
    var dailyOrders: [SupabaseDailyOrderDTO]
    var dailyChecklistItems: [SupabaseDailyChecklistItemDTO]
}
