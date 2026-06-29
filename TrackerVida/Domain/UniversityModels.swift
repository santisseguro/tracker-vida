import Foundation

enum CourseStatus: String, CaseIterable, Codable, Identifiable {
    case planned = "Planned"
    case active = "Active"
    case completed = "Completed"
    case dropped = "Dropped"

    var id: String { rawValue }
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
