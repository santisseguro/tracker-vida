import SwiftUI

struct UniversityView: View {
    @EnvironmentObject private var store: AppStore
    @State private var activeSheet: UniversitySheet?

    private var state: UniversityViewState { store.universityState }

    var body: some View {
        ScreenScaffold(
            title: "Study Cockpit",
            subtitle: "Critical tasks, upcoming deadlines, replies, and timeline preview."
        ) {
            AICommandBar(
                context: .university,
                latestCommand: store.latestCapturedAICommand(for: .university)
            ) { command in
                store.captureAICommand(command, context: .university)
                return true
            }

            AppCard(tint: AppTheme.Colors.university) {
                HStack {
                    StatusPill(text: "Focus block", tint: AppTheme.Colors.university)
                    Spacer()
                    Text("\(state.activeCriticalTasks.count) critical")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(AppTheme.Colors.university)
                }

                Text("Clear the urgent lane first.")
                    .font(.title.weight(.bold))
                ProgressView(value: 0.36)
                    .tint(AppTheme.Colors.university)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                activeSheet = .addTask
            }

            AppCard(tint: AppTheme.Colors.primary, compact: true) {
                HStack {
                    Text("Class schedule")
                        .font(.headline.weight(.bold))
                    Spacer()
                    Button {
                        activeSheet = .addClass
                    } label: {
                        Label("Add class", systemImage: "plus.circle.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppTheme.Colors.primary)
                    }
                    .buttonStyle(.plain)
                }

                if !state.todayClasses.isEmpty {
                    ForEach(state.todayClasses) { scheduledClass in
                        ScheduledClassRow(scheduledClass: scheduledClass, tint: tint(for: scheduledClass.universityClass))
                    }
                } else if let nextClass = state.upcomingClassesThisWeek.first {
                    Text("Next up")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                    ScheduledClassRow(scheduledClass: nextClass, tint: tint(for: nextClass.universityClass), showsWeekday: true)
                } else {
                    Text("No classes scheduled yet.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                WeeklySchedulePreview(classes: state.classes, scheduledClasses: state.upcomingClassesThisWeek)
            }

            AppCard {
                Text("Academic board")
                    .font(.headline.weight(.bold))

                ForEach(state.activeCriticalTasks) { task in
                    InfoRow(title: task.title, detail: task.category.rawValue, value: task.priority.rawValue, symbol: "exclamationmark.circle.fill", tint: AppTheme.Colors.university)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            activeSheet = .editTask(task.id)
                        }
                        .contextMenu {
                            Button("Mark completed") {
                                store.markAcademicTaskCompleted(task.id)
                            }
                        }
                }

                Divider()

                ForEach(state.upcomingDeadlines) { task in
                    InfoRow(title: task.title, detail: task.category.rawValue, value: task.dueDate?.formatted(date: .abbreviated, time: .omitted), symbol: "calendar", tint: AppTheme.Colors.primary)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            activeSheet = .editTask(task.id)
                        }
                        .contextMenu {
                            Button("Mark completed") {
                                store.markAcademicTaskCompleted(task.id)
                            }
                        }
                }
            }

            AppCard(tint: AppTheme.Colors.warning, compact: true) {
                HStack {
                    Text("Waiting for response")
                        .font(.headline.weight(.bold))
                    Spacer()
                    StatusPill(text: "\(state.waitingResponses.count) open", tint: AppTheme.Colors.warning)
                }

                ForEach(state.waitingResponses) { item in
                    InfoRow(title: item.title, detail: item.detail, value: item.value, symbol: "envelope.fill", tint: AppTheme.Colors.warning)
                }
            }

            AppCard(tint: AppTheme.Colors.ai) {
                Text("Timeline preview")
                    .font(.headline.weight(.bold))
                ForEach(state.timeline) { item in
                    InfoRow(title: item.title, detail: item.detail, value: item.value, symbol: "clock.fill", tint: AppTheme.Colors.ai)
                }
            }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .addTask, .editTask:
                UniversityTaskFormView(sheet: sheet)
                    .environmentObject(store)
            case .addClass:
                UniversityClassFormView()
                    .environmentObject(store)
            }
        }
    }

    private func tint(for universityClass: UniversityClass) -> Color {
        universityClass.color?.tint ?? AppTheme.Colors.university
    }
}

private enum UniversitySheet: Identifiable {
    case addTask
    case editTask(EntityID)
    case addClass

    var id: String {
        switch self {
        case .addTask:
            return "add-task"
        case let .editTask(taskID):
            return "edit-task-\(taskID.uuidString)"
        case .addClass:
            return "add-class"
        }
    }
}

private struct ScheduledClassRow: View {
    var scheduledClass: UniversityScheduledClass
    var tint: Color
    var showsWeekday = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "book.closed.fill")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(tint.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(scheduledClass.universityClass.name)
                    .font(.subheadline.weight(.semibold))

                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }

            Spacer(minLength: 12)

            Text(timeRangeText(for: scheduledClass.session))
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var detail: String {
        let prefix = showsWeekday ? "\(scheduledClass.session.weekday.shortName) · " : ""

        if let location = scheduledClass.location {
            return "\(prefix)\(location)"
        }

        if let instructor = scheduledClass.universityClass.instructor {
            return "\(prefix)\(instructor)"
        }

        return "\(prefix)Weekly"
    }
}

private struct WeeklySchedulePreview: View {
    var classes: [UniversityClass]
    var scheduledClasses: [UniversityScheduledClass]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(UniversityWeekday.allCases) { weekday in
                let count = scheduledClasses.filter { $0.session.weekday == weekday }.count
                VStack(spacing: 6) {
                    Text(weekday.shortName.prefix(1))
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)

                    Circle()
                        .fill(count > 0 ? tint(for: weekday) : Color.secondary.opacity(0.18))
                        .frame(width: 7, height: 7)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.top, 4)
        .accessibilityLabel("Weekly class schedule preview")
    }

    private func tint(for weekday: UniversityWeekday) -> Color {
        guard let scheduledClass = scheduledClasses.first(where: { $0.session.weekday == weekday }) else {
            return .secondary.opacity(0.18)
        }

        return scheduledClass.universityClass.color?.tint ?? AppTheme.Colors.university
    }
}

private struct UniversityTaskDraft {
    var title: String
    var category: AcademicTaskCategory
    var status: AcademicTaskStatus
    var priority: AcademicTaskPriority
    var hasDeadline: Bool
    var dueDate: Date
    var notes: String
    var waitingSince: Date

    init(task: AcademicTask?, currentDate: Date) {
        title = task?.title ?? ""
        category = task?.category ?? .academic
        status = task?.status ?? .pending
        priority = task?.priority ?? .medium
        hasDeadline = task?.dueDate != nil
        dueDate = task?.dueDate ?? currentDate
        notes = task?.notes ?? ""
        waitingSince = task?.waitingSince ?? currentDate
    }
}

private struct UniversityClassDraft {
    var name = ""
    var instructor = ""
    var location = ""
    var weekday: UniversityWeekday = .monday
    var startTime: Date
    var endTime: Date
    var notes = ""

    init(currentDate: Date) {
        startTime = Self.date(on: currentDate, hour: 9, minute: 0)
        endTime = Self.date(on: currentDate, hour: 10, minute: 30)
    }

    private static func date(on date: Date, hour: Int, minute: Int) -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return calendar.date(
            from: DateComponents(
                year: components.year,
                month: components.month,
                day: components.day,
                hour: hour,
                minute: minute
            )
        ) ?? date
    }
}

private struct UniversityClassFormView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft: UniversityClassDraft

    init() {
        _draft = State(initialValue: UniversityClassDraft(currentDate: .now))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Class") {
                    TextField("Class name", text: $draft.name)
                    TextField("Instructor optional", text: $draft.instructor)
                    TextField("Location optional", text: $draft.location)
                }

                Section("Schedule") {
                    Picker("Weekday", selection: $draft.weekday) {
                        ForEach(UniversityWeekday.allCases) { weekday in
                            Text(weekday.fullName).tag(weekday)
                        }
                    }

                    DatePicker("Starts", selection: $draft.startTime, displayedComponents: .hourAndMinute)
                    DatePicker("Ends", selection: $draft.endTime, displayedComponents: .hourAndMinute)
                }

                Section("Note") {
                    TextField("Optional note", text: $draft.notes, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle("New class")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
            .onAppear {
                draft = UniversityClassDraft(currentDate: store.currentDate)
            }
        }
    }

    private var canSave: Bool {
        !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && endMinute > startMinute
    }

    private var startMinute: Int {
        minuteOfDay(from: draft.startTime)
    }

    private var endMinute: Int {
        minuteOfDay(from: draft.endTime)
    }

    private func save() {
        let universityClass = store.addUniversityClass(
            name: draft.name,
            instructor: draft.instructor,
            location: draft.location,
            color: .university,
            notes: draft.notes,
            createdAt: store.currentDate
        )

        store.addUniversityScheduleSession(
            classID: universityClass.id,
            weekday: draft.weekday,
            startMinuteOfDay: startMinute,
            endMinuteOfDay: endMinute,
            createdAt: store.currentDate
        )
    }
}

private struct UniversityTaskFormView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft: UniversityTaskDraft

    private let sheet: UniversitySheet

    init(sheet: UniversitySheet) {
        self.sheet = sheet
        _draft = State(initialValue: UniversityTaskDraft(task: nil, currentDate: .now))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Task") {
                    TextField("Title", text: $draft.title)

                    Picker("Category", selection: $draft.category) {
                        ForEach(AcademicTaskCategory.allCases) { category in
                            Text(category.rawValue).tag(category)
                        }
                    }
                }

                Section("State") {
                    Picker("Status", selection: $draft.status) {
                        ForEach(AcademicTaskStatus.allCases) { status in
                            Text(status.rawValue).tag(status)
                        }
                    }

                    Picker("Priority", selection: $draft.priority) {
                        ForEach(AcademicTaskPriority.allCases) { priority in
                            Text(priority.rawValue).tag(priority)
                        }
                    }

                    if draft.status == .waitingResponse {
                        DatePicker("Waiting since", selection: $draft.waitingSince, displayedComponents: .date)
                    }
                }

                Section("Deadline") {
                    Toggle("Has deadline", isOn: $draft.hasDeadline)

                    if draft.hasDeadline {
                        DatePicker("Deadline", selection: $draft.dueDate, displayedComponents: .date)
                    }
                }

                Section("Note") {
                    TextField("Simple note", text: $draft.notes, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                        dismiss()
                    }
                    .disabled(draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                loadDraft()
            }
        }
    }

    private var navigationTitle: String {
        switch sheet {
        case .addTask:
            return "New task"
        case .editTask:
            return "Edit task"
        case .addClass:
            return "Task"
        }
    }

    private func loadDraft() {
        switch sheet {
        case .addTask:
            draft = UniversityTaskDraft(task: nil, currentDate: store.currentDate)
        case let .editTask(taskID):
            draft = UniversityTaskDraft(task: store.universityTask(id: taskID), currentDate: store.currentDate)
        case .addClass:
            draft = UniversityTaskDraft(task: nil, currentDate: store.currentDate)
        }
    }

    private func save() {
        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let dueDate = draft.hasDeadline ? draft.dueDate : nil
        let waitingSince = draft.status == .waitingResponse ? draft.waitingSince : nil

        switch sheet {
        case .addTask:
            store.addUniversityTask(
                title: title,
                category: draft.category,
                status: draft.status,
                priority: draft.priority,
                dueDate: dueDate,
                notes: draft.notes,
                waitingSince: waitingSince
            )
        case let .editTask(taskID):
            guard var task = store.universityTask(id: taskID) else { return }

            task.title = title
            task.category = draft.category
            task.status = draft.status
            task.priority = draft.priority
            task.dueDate = dueDate
            task.notes = draft.notes
            task.waitingSince = waitingSince

            store.updateUniversityTask(task)
        case .addClass:
            break
        }
    }
}

private func timeRangeText(for session: UniversityScheduleSession) -> String {
    "\(timeText(for: session.startMinuteOfDay))-\(timeText(for: session.endMinuteOfDay))"
}

private func timeText(for minuteOfDay: Int) -> String {
    let hour = minuteOfDay / 60
    let minute = minuteOfDay % 60
    return String(format: "%02d:%02d", hour, minute)
}

private func minuteOfDay(from date: Date) -> Int {
    let calendar = Calendar.current
    let components = calendar.dateComponents([.hour, .minute], from: date)
    return ((components.hour ?? 0) * 60) + (components.minute ?? 0)
}

private extension UniversityClassColor {
    var tint: Color {
        switch self {
        case .university:
            return AppTheme.Colors.university
        case .primary:
            return AppTheme.Colors.primary
        case .health:
            return AppTheme.Colors.health
        case .warning:
            return AppTheme.Colors.warning
        case .ai:
            return AppTheme.Colors.ai
        }
    }
}
