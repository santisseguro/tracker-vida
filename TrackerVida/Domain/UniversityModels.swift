import Foundation

enum CourseStatus: String, CaseIterable, Codable, Identifiable {
    case planned = "Planned"
    case active = "Active"
    case completed = "Completed"
    case dropped = "Dropped"

    var id: String { rawValue }
}

enum AcademicTaskType: String, CaseIterable, Codable, Identifiable {
    case assignment = "Assignment"
    case exam = "Exam"
    case reading = "Reading"
    case project = "Project"
    case study = "Study"
    case admin = "Admin"
    case other = "Other"

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
    var type: AcademicTaskType
    var status: CompletionStatus
    var priority: PriorityLevel
    var dueDate: Date? = nil
    var completedAt: Date? = nil
    var notes: String? = nil
    var links: [LinkedResource] = []

    var id: EntityID { metadata.id }
    var isComplete: Bool { status == .done || status == .skipped }

    func isOverdue(referenceDate: Date, calendar: Calendar = .current) -> Bool {
        guard let dueDate, !isComplete else { return false }
        return calendar.startOfDay(for: dueDate) < calendar.startOfDay(for: referenceDate)
    }
}
