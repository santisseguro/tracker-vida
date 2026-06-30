import Foundation

enum WorkoutType: String, CaseIterable, Codable, Identifiable {
    case push = "Push"
    case pull = "Pull"
    case legs = "Legs"
    case fullBody = "Full Body"
    case cardio = "Cardio"
    case other = "Other"

    var id: String { rawValue }
}

enum SleepQuality: String, CaseIterable, Codable, Identifiable {
    case good = "Good"
    case normal = "Normal"
    case bad = "Bad"

    var id: String { rawValue }
}

enum HealthEntrySource: String, CaseIterable, Codable, Identifiable {
    case manual = "Manual"
    case appleHealth = "Apple Health"

    var id: String { rawValue }
}

struct HealthSourceMetadata: Codable, Hashable {
    var source: HealthEntrySource
    var importedAt: Date? = nil
    var externalID: String? = nil
    var deviceName: String? = nil
}

struct LateEntryMetadata: Codable, Hashable {
    var isLateEntry: Bool
    var originalEntryDate: Date
    var enteredAt: Date
    var reason: String? = nil
}

struct WeightLog: Codable, Hashable, Identifiable {
    var metadata: BaseMetadata
    var date: Date
    var weightKg: Double
    var source: HealthSourceMetadata
    var lateEntry: LateEntryMetadata? = nil
    var notes: String? = nil

    var id: EntityID { metadata.id }
}

struct WeightGoal: Codable, Hashable, Identifiable {
    var metadata: BaseMetadata
    var targetWeightKg: Double
    var startWeightKg: Double? = nil
    var startDate: Date
    var targetDate: Date? = nil
    var gymDayCalorieTarget: Int
    var restDayCalorieTarget: Int
    var targetWorkoutsPerWeek: Int
    var idealGymWeekdays: [Int]
    var isActive: Bool
    var notes: String? = nil

    var id: EntityID { metadata.id }

    init(
        metadata: BaseMetadata,
        targetWeightKg: Double,
        startWeightKg: Double? = nil,
        startDate: Date,
        targetDate: Date? = nil,
        gymDayCalorieTarget: Int = 2_300,
        restDayCalorieTarget: Int = 2_000,
        targetWorkoutsPerWeek: Int = 5,
        idealGymWeekdays: [Int] = [2, 3, 4, 5, 6],
        isActive: Bool,
        notes: String? = nil
    ) {
        self.metadata = metadata
        self.targetWeightKg = targetWeightKg
        self.startWeightKg = startWeightKg
        self.startDate = startDate
        self.targetDate = targetDate
        self.gymDayCalorieTarget = gymDayCalorieTarget
        self.restDayCalorieTarget = restDayCalorieTarget
        self.targetWorkoutsPerWeek = targetWorkoutsPerWeek
        self.idealGymWeekdays = idealGymWeekdays
        self.isActive = isActive
        self.notes = notes
    }

    private enum CodingKeys: String, CodingKey {
        case metadata
        case targetWeightKg
        case startWeightKg
        case startDate
        case targetDate
        case gymDayCalorieTarget
        case restDayCalorieTarget
        case targetWorkoutsPerWeek
        case idealGymWeekdays
        case isActive
        case notes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        metadata = try container.decode(BaseMetadata.self, forKey: .metadata)
        targetWeightKg = try container.decode(Double.self, forKey: .targetWeightKg)
        startWeightKg = try container.decodeIfPresent(Double.self, forKey: .startWeightKg)
        startDate = try container.decode(Date.self, forKey: .startDate)
        targetDate = try container.decodeIfPresent(Date.self, forKey: .targetDate)
        gymDayCalorieTarget = try container.decodeIfPresent(Int.self, forKey: .gymDayCalorieTarget) ?? 2_300
        restDayCalorieTarget = try container.decodeIfPresent(Int.self, forKey: .restDayCalorieTarget) ?? 2_000
        targetWorkoutsPerWeek = try container.decodeIfPresent(Int.self, forKey: .targetWorkoutsPerWeek) ?? 5
        idealGymWeekdays = try container.decodeIfPresent([Int].self, forKey: .idealGymWeekdays) ?? [2, 3, 4, 5, 6]
        isActive = try container.decode(Bool.self, forKey: .isActive)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
    }
}

struct DailyHealthLog: Codable, Hashable, Identifiable {
    var metadata: BaseMetadata
    var date: Date
    var totalCalories: Int? = nil
    var gymAttended: Bool
    var workoutDurationMinutes: Int? = nil
    var workoutType: WorkoutType? = nil
    var sleepHours: Double? = nil
    var sleepQuality: SleepQuality? = nil
    var source: HealthSourceMetadata
    var lateEntry: LateEntryMetadata? = nil
    var notes: String? = nil

    var id: EntityID { metadata.id }
}

extension Array where Element == DailyHealthLog {
    var gymAttendanceCount: Int {
        filter(\.gymAttended).count
    }

    var averageSleepHours: Double {
        let values = compactMap(\.sleepHours)
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    var totalCalories: Int {
        compactMap(\.totalCalories).reduce(0, +)
    }
}

extension Array where Element == WeightLog {
    var latest: WeightLog? {
        sorted { $0.date < $1.date }.last
    }
}
