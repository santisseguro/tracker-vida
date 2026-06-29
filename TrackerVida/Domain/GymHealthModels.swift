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
    var isActive: Bool
    var notes: String? = nil

    var id: EntityID { metadata.id }
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
