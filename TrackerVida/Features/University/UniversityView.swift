import SwiftUI

struct UniversityView: View {
    @EnvironmentObject private var store: AppStore
    @State private var activeSheet: UniversityTaskSheet?

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
                activeSheet = .add
            }

            AppCard {
                Text("Academic board")
                    .font(.headline.weight(.bold))

                ForEach(state.activeCriticalTasks) { task in
                    InfoRow(title: task.title, detail: task.category.rawValue, value: task.priority.rawValue, symbol: "exclamationmark.circle.fill", tint: AppTheme.Colors.university)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            activeSheet = .edit(task.id)
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
                            activeSheet = .edit(task.id)
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
            UniversityTaskFormView(sheet: sheet)
                .environmentObject(store)
        }
    }
}

private enum UniversityTaskSheet: Identifiable {
    case add
    case edit(EntityID)

    var id: String {
        switch self {
        case .add:
            return "add"
        case let .edit(taskID):
            return taskID.uuidString
        }
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

private struct UniversityTaskFormView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft: UniversityTaskDraft

    private let sheet: UniversityTaskSheet

    init(sheet: UniversityTaskSheet) {
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
        case .add:
            return "New task"
        case .edit:
            return "Edit task"
        }
    }

    private func loadDraft() {
        switch sheet {
        case .add:
            draft = UniversityTaskDraft(task: nil, currentDate: store.currentDate)
        case let .edit(taskID):
            draft = UniversityTaskDraft(task: store.universityTask(id: taskID), currentDate: store.currentDate)
        }
    }

    private func save() {
        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let dueDate = draft.hasDeadline ? draft.dueDate : nil
        let waitingSince = draft.status == .waitingResponse ? draft.waitingSince : nil

        switch sheet {
        case .add:
            store.addUniversityTask(
                title: title,
                category: draft.category,
                status: draft.status,
                priority: draft.priority,
                dueDate: dueDate,
                notes: draft.notes,
                waitingSince: waitingSince
            )
        case let .edit(taskID):
            guard var task = store.universityTask(id: taskID) else { return }

            task.title = title
            task.category = draft.category
            task.status = draft.status
            task.priority = draft.priority
            task.dueDate = dueDate
            task.notes = draft.notes
            task.waitingSince = waitingSince

            store.updateUniversityTask(task)
        }
    }
}
