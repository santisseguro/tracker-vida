import Foundation

enum CourseStatus: String, CaseIterable, Codable, Identifiable {
    case planned = "Planned"
    case active = "Active"
    case completed = "Completed"
    case dropped = "Dropped"

    var id: String { rawValue }
}

enum UniversityClassStatus: String, CaseIterable, Codable, Identifiable {
    case active = "Active"
    case archived = "Archived"

    var id: String { rawValue }
}

enum UniversityClassColor: String, CaseIterable, Codable, Identifiable {
    case university
    case primary
    case health
    case warning
    case ai

    var id: String { rawValue }
}

enum UniversityWeekday: Int, CaseIterable, Codable, Identifiable, Comparable {
    case sunday = 1
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7

    var id: Int { rawValue }

    var shortName: String {
        switch self {
        case .sunday:
            return "Sun"
        case .monday:
            return "Mon"
        case .tuesday:
            return "Tue"
        case .wednesday:
            return "Wed"
        case .thursday:
            return "Thu"
        case .friday:
            return "Fri"
        case .saturday:
            return "Sat"
        }
    }

    var fullName: String {
        switch self {
        case .sunday:
            return "Sunday"
        case .monday:
            return "Monday"
        case .tuesday:
            return "Tuesday"
        case .wednesday:
            return "Wednesday"
        case .thursday:
            return "Thursday"
        case .friday:
            return "Friday"
        case .saturday:
            return "Saturday"
        }
    }

    static func < (lhs: UniversityWeekday, rhs: UniversityWeekday) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

struct UniversityClass: Codable, Hashable, Identifiable {
    var metadata: BaseMetadata
    var name: String
    var shortName: String? = nil
    var instructor: String? = nil
    var location: String? = nil
    var color: UniversityClassColor? = nil
    var status: UniversityClassStatus = .active
    var notes: String? = nil

    var id: EntityID { metadata.id }
}

struct UniversityScheduleSession: Codable, Hashable, Identifiable {
    var metadata: BaseMetadata
    var classID: EntityID
    var weekday: UniversityWeekday
    var startMinuteOfDay: Int
    var endMinuteOfDay: Int
    var locationOverride: String? = nil

    var id: EntityID { metadata.id }
}

struct UniversityScheduledClass: Hashable, Identifiable {
    var session: UniversityScheduleSession
    var universityClass: UniversityClass
    var occurrenceDate: Date

    var id: EntityID { session.id }

    var location: String? {
        session.locationOverride ?? universityClass.location
    }
}

enum AcademicTaskCategory: String, CaseIterable, Codable, Identifiable {
    case academic = "Académico"
    case admin = "Trámite"
    case document = "Documento"
    case deadline = "Deadline"
    case email = "Email"
    case other = "Otro"

    var id: String { rawValue }
}

enum AcademicTaskPriority: String, CaseIterable, Codable, Identifiable {
    case critical = "Crítica"
    case high = "Alta"
    case medium = "Media"
    case low = "Baja"

    var id: String { rawValue }
}

enum AcademicTaskStatus: String, CaseIterable, Codable, Identifiable {
    case pending = "Pendiente"
    case inProgress = "En progreso"
    case waitingResponse = "Esperando respuesta"
    case completed = "Completada"

    var id: String { rawValue }
}

struct Course: Codable, Hashable, Identifiable {
    var metadata: BaseMetadata
    var name: String
    var code: String? = nil
    var term: String? = nil
    var instructor: String? = nil
    var status: CourseStatus
    var notes: String? = nil
    var links: [LinkedResource] = []

    var id: EntityID { metadata.id }
}

struct AcademicTask: Codable, Hashable, Identifiable {
    var metadata: BaseMetadata
    var courseID: EntityID? = nil
    var title: String
    var category: AcademicTaskCategory
    var status: AcademicTaskStatus
    var priority: AcademicTaskPriority
    var dueDate: Date? = nil
    var waitingSince: Date? = nil
    var completedAt: Date? = nil
    var notes: String? = nil
    var links: [LinkedResource] = []

    var id: EntityID { metadata.id }
    var isComplete: Bool { status == .completed }

    func isOverdue(referenceDate: Date, calendar: Calendar = .current) -> Bool {
        guard let dueDate, !isComplete else { return false }
        return calendar.startOfDay(for: dueDate) < calendar.startOfDay(for: referenceDate)
    }
}
